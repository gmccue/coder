package provisionersdk

import (
	"fmt"

	"github.com/coder/coder/v2/provisionersdk/proto"
)

func ParseErrorf(format string, args ...any) *proto.ParseComplete {
	return &proto.ParseComplete{Error: fmt.Sprintf(format, args...)}
}

func PlanErrorf(format string, args ...any) *proto.PlanComplete {
	return &proto.PlanComplete{Error: fmt.Sprintf(format, args...)}
}

func ApplyErrorf(format string, args ...any) *proto.ApplyComplete {
	return &proto.ApplyComplete{Error: fmt.Sprintf(format, args...)}
}

func AllocatePlanErrorf(format string, args ...any) *proto.AllocatePlanComplete {
	return &proto.AllocatePlanComplete{Error: fmt.Sprintf(format, args...)}
}

func AllocateApplyErrorf(format string, args ...any) *proto.AllocateApplyComplete {
	return &proto.AllocateApplyComplete{Error: fmt.Sprintf(format, args...)}
}
