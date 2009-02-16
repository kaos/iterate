-module(element_backlog_edit).
-compile(export_all).

-include_lib("nitrogen/include/wf.inc").
-include("elements.hrl").
-include("macros.hrl").
-include("iterate_records.hrl").

render(ControlId, Record) ->
    %% TODO(jwall): change to temp ids wf:temp_id()
    Id       = Record#backlog_edit.backlog_id
    , ElId     = Record#backlog_edit.el_id
    , Name     = Id ++ "_BacklogEditBox"
    , ButtonId = Name ++ "CloseButton"
    , Button   = #button{ 
        id=ButtonId
        , text="close"
        , actions=#event{ type=click
                  , delegate=element_backlog
                  , postback=?REMOVE_B_EL(Id, ElId)
                }
    }
    , Panel = #panel{ id=Name,
        body=[
           #my_inplace_textbox{ tag=?UPDATEDESC(Id),
                delegate=?MODULE, text=Record#backlog_edit.desc }, #br{}
           , Button
        ]
    }
    , element_panel:render(ControlId, Panel)
.

inplace_textbox_event(?UPDATEDESC(Name), Value) ->
    io:format("updating desc for ~s", [Name]),
    case iterate_db:backlog({qry, Name}) of
        %%{error, Msg} ->
            %% what do I do for this one?
        [B | []] ->
            B1 = B#backlogs{desc=Value},
            iterate_db:backlog({update, B1})
    end,
    Value
.

