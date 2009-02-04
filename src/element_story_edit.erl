-module(element_story_edit).
-compile(export_all).

-include_lib("nitrogen/include/wf.inc").
-include("elements.hrl").

render(ControlId, Record) ->
    %% TODO(jwall): change to temp ids wf:temp_id()
    PanelId        = wf:temp_id(),
    Name           = Record#story_edit.story_name,
    Desc           = Record#story_edit.desc,
    StoryPoints    = Record#story_edit.sp,
    Panel = #panel{ id=PanelId,
                    body=[
                        Name, #br{}
                        , Desc, #br{}
                        , StoryPoints, #br{}
                    ]
    },
    element_panel:render(ControlId, Panel).

event(_) -> ok.
