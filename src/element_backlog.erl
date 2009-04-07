-module(element_backlog).
-compile(export_all).

-include_lib("nitrogen/include/wf.inc").
-include("stats.hrl").
-include("elements.hrl").
-include("events.hrl").
-include("iterate_records.hrl").

render(_ControlId, Record) ->
    Name    = Record#backlog.backlog_name
    , PanelId = wf:temp_id()
    , Panel = #delegated_droppable{ id=PanelId
        , hover_class=drop_hover
        , tag={Name, {delegate, ?MODULE}}
        , body=body(Name, PanelId) }
    , io:format("the panel id for ~s is ~s~n", [Name, PanelId])
    , element_delegated_droppable:render(PanelId, Panel).

body(Name, PanelId) ->
    {Type, _TypeName} = story_util:get_type(iterate_wf:get_story(Name))
    , [#panel{ id=PanelId, actions=#event{type=click
                   , delegate=element_story_panel
                   , postback=?SHOW_STORIES(Type, Name)
            }
            , body=[#label{ id=Name ++ "_name", text=Name}
                , " " , #link{text="edit"
                        , actions=#event{type=click, delegate=?MODULE
                            , postback=?SHOW_B_EL(Name, PanelId)
                        }
                }
                , " " , #link{text="delete"
                        , actions=#event{type=click, delegate=?MODULE
                            , postback=?DELETE_B_EL(Name, PanelId)
                        }
                }
            ]
    }
    , #panel{id=Name ++ "_target"}].

%% showing backlog info
event(?UPDATE_B_EL(Name, Id)) ->
    io:format("updating backlog widget ~s for: ~s~n", [Id, Name])
    , case iterate_db:backlog({qry, Name}) of
        [_ | []] ->
            wf:update(Id, body(Name, Id))
    end;
event(?SHOW_B_EL(Name, Id)) ->
    io:format("showing edit widget for: ~s~n", [Name])
    , case iterate_db:backlog({qry, Name}) of
        [B | []] ->
            wf:update(Name ++ "_target",
                #backlog_edit{ backlog_id=Name, el_id=Id, desc=B#backlogs.desc })
    end;
event(?DELETE_B_EL(Name, Id)) ->
    % TODO(jwall): do something with attempts to delete the permanent backlogs
    io:format("hiding element: ~p~n", [Id])
    , wf:wire(Id, #hide{ effect=slide, speed=500 })
    , iterate_wf:delete_backlog(Name)
    , event(?REMOVE_B_EL(Name, Id));
event(?REMOVE_B_EL(Name, _Id)) ->
    wf:update(Name ++ "_target", "");
event(Event) -> 
    io:format("received event: ~p~n", [Event])
.

%% move a story to a backlog
drop_event(Story, Backlog) ->
    io:format("received event: ~p -> ~p~n", [Story, Backlog])
    , {old_backlog, OldBacklog} = 
        iterate_wf:move_story_to_backlog(Story, Backlog)
    , {Type, _Name} = story_util:get_type(iterate_wf:get_story(Story))
    , element_story_panel:event(?SHOW_STORIES(Type, OldBacklog))
    , ok
.

