package idpsync

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"golang.org/x/xerrors"

	"cdr.dev/slog"
	"github.com/coder/coder/v2/coderd/database"
	"github.com/coder/coder/v2/coderd/database/db2sdk"
	"github.com/coder/coder/v2/coderd/database/dbauthz"
	"github.com/coder/coder/v2/coderd/database/dbtime"
	"github.com/coder/coder/v2/coderd/util/slice"
)

func (s AGPLIDPSync) ParseOrganizationClaims(ctx context.Context, _ map[string]interface{}) (OrganizationParams, *HttpError) {
	// nolint:gocritic // all syncing is done as a system user
	ctx = dbauthz.AsSystemRestricted(ctx)

	// For AGPL we only sync the default organization.
	return OrganizationParams{
		SyncEnabled:    false,
		IncludeDefault: s.OrganizationAssignDefault,
		Organizations:  []uuid.UUID{},
	}, nil
}

type OrganizationParams struct {
	// SyncEnabled if false will skip syncing the user's organizations.
	SyncEnabled    bool
	IncludeDefault bool
	// Organizations is the list of organizations the user should be a member of
	// assuming syncing is turned on.
	Organizations []uuid.UUID
}

func (s AGPLIDPSync) SyncOrganizations(ctx context.Context, tx database.Store, user database.User, params OrganizationParams) error {
	// Nothing happens if sync is not enabled
	if !params.SyncEnabled {
		return nil
	}

	// nolint:gocritic // all syncing is done as a system user
	ctx = dbauthz.AsSystemRestricted(ctx)

	// This is a bit hacky, but if AssignDefault is included, then always
	// make sure to include the default org in the list of expected.
	if s.OrganizationAssignDefault {
		defaultOrg, err := tx.GetDefaultOrganization(ctx)
		if err != nil {
			return xerrors.Errorf("failed to get default organization: %w", err)
		}
		params.Organizations = append(params.Organizations, defaultOrg.ID)
	}

	existingOrgs, err := tx.GetOrganizationsByUserID(ctx, user.ID)
	if err != nil {
		return xerrors.Errorf("failed to get user organizations: %w", err)
	}

	existingOrgIDs := db2sdk.List(existingOrgs, func(org database.Organization) uuid.UUID {
		return org.ID
	})

	// Find the difference in the expected and the existing orgs, and
	// correct the set of orgs the user is a member of.
	add, remove := slice.SymmetricDifference(existingOrgIDs, params.Organizations)
	notExists := make([]uuid.UUID, 0)
	for _, orgID := range add {
		//nolint:gocritic // System actor being used to assign orgs
		_, err := tx.InsertOrganizationMember(dbauthz.AsSystemRestricted(ctx), database.InsertOrganizationMemberParams{
			OrganizationID: orgID,
			UserID:         user.ID,
			CreatedAt:      dbtime.Now(),
			UpdatedAt:      dbtime.Now(),
			Roles:          []string{},
		})
		if err != nil {
			if xerrors.Is(err, sql.ErrNoRows) {
				notExists = append(notExists, orgID)
				continue
			}
			return xerrors.Errorf("add user to organization: %w", err)
		}
	}

	for _, orgID := range remove {
		//nolint:gocritic // System actor being used to assign orgs
		err := tx.DeleteOrganizationMember(dbauthz.AsSystemRestricted(ctx), database.DeleteOrganizationMemberParams{
			OrganizationID: orgID,
			UserID:         user.ID,
		})
		if err != nil {
			return xerrors.Errorf("remove user from organization: %w", err)
		}
	}

	if len(notExists) > 0 {
		s.Logger.Debug(ctx, "organizations do not exist but attempted to use in org sync",
			slog.F("not_found", notExists),
			slog.F("user_id", user.ID),
			slog.F("username", user.Username),
		)
	}
	return nil
}