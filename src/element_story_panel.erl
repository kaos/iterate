-module(element_story_panel).
-compile(export_all).

-include_lib("nitrogen/include/wf.inc").
-include("events.hrl").
-include("elements.hrl").
-include("iterate_records.hrl").

render(ControlId, Record) ->
    PanelId = wf:temp_id()
    , Data    = case Record#story_panel.data of
        undefined ->
            [];
        D when is_list(D) ->
            D
    end
    , Panel = #rounded_panel{ id=PanelId,
        body=[#label{text="Stories"}, 
              #panel{id=?SPANELID, body=stories(Data) }]
    }
    , element_rounded_panel:render(ControlId, Panel)
.

stories(L) ->
    stories(L, {backlog, undefined}).

stories([], {Type, Name}) ->
    %%wf:flash("showing stories for " ++ atom_to_list(Type) ++ ": " ++ Name)
    [#link{ text="create"
        , actions=#event{
            type=click, delegate=?MODULE
            , postback=?S_PANEL_CREATE(Type, Name)
        }}, " "
     , #link{ text="refresh"
        , actions=#event{
            type=click, delegate=?MODULE
            , postback=?SHOW_STORIES(Name)
        }}
    ]; 
stories([H|T], {Type, Name}) ->
    [ #story{story_name=H, backlog=Name} 
        | stories(T, {Type, Name}) ];
stories(L, Name) ->
    stories(L, {backlog, Name})
.

%% showing stories
event(?SHOW_STORIES(Name)) ->
    StoryList = [ S#stories.story_name || S <- 
        iterate_db:story(?Q_BACKLOG_STORY(Name)) ],
    wf:update(story_list, stories(StoryList, {backlog, Name}) );
event(?SHOW_ITERATION_STORIES(Name)) ->
    StoryList = [ S#stories.story_name || S <- 
        iterate_db:story(?Q_ITERATION_STORY(Name)) ],
    wf:update(story_list, stories(StoryList, {iteration, Name}) );
event(?S_PANEL_CREATE(_Type, undefined)) ->
    wf:flash("can't create stories without a backlog or iteration");
event(?S_PANEL_CREATE(iteration, Backlog)) ->
    %% we need a create story widget
    TB_Id = wf:temp_id(),
    PanelId = wf:temp_id(),
    ButtonId = wf:temp_id(),
    wf:flash(#panel{ id=PanelId
        , body=[
            "creating story for iteration: " ++ Backlog, #br{ }
            , #textbox{ id=TB_Id, next=ButtonId,  text="Enter Name Here"}
            , #button{ id=ButtonId,
                text="Create",
                actions=#event{ delegate=?MODULE,
                    type=click, postback=?CREATE_S(TB_Id, PanelId
                        , {iteration, Backlog})}
        }]
    }),
    ok;
event(?S_PANEL_CREATE(backlog, Backlog)) ->
    %% we need a create story widget
    TB_Id = wf:temp_id(),
    PanelId = wf:temp_id(),
    ButtonId = wf:temp_id(),
    wf:flash(#panel{ id=PanelId
        , body=[
            "creating story for backlog: " ++ Backlog, #br{ }
            , #textbox{ id=TB_Id, next=ButtonId,  text="Enter Name Here"}
            , #button{ id=ButtonId,
                text="Create",
                actions=#event{ delegate=?MODULE,
                    type=click, postback=?CREATE_S(TB_Id, PanelId
                        , {backlog, Backlog})}
        }]
    }),
    ok;
event(?CREATE_S(Id, PanelId, {iteration, Backlog})) ->
    [Value] = wf:q(Id)
    , Story = story_util:set_iteration(#stories{story_name=Value}, Backlog)
    , case iterate_db:story({new, Story}) of
        {error, Msg} ->
            wf:update(PanelId, "Failed!!")
            , wf:flash(io_lib:format("~p", [Msg]));
        {atomic, ok} ->
            wf:update(PanelId, io_lib:format("Story ~p Created", [Value]))
            , wf:insert_top(?SPANELID, #story{story_name=Value});
        _ ->
            throw({error, unknown})
    end
    , ok;
event(?CREATE_S(Id, PanelId, {backlog, Backlog})) ->
    [Value] = wf:q(Id)
    , Story = story_util:set_backlog(#stories{story_name=Value}, Backlog)
    , case iterate_db:story({new, Story}) of
        {error, Msg} ->
            wf:update(PanelId, "Failed!!")
            , wf:flash(io_lib:format("~p", [Msg]));
        {atomic, ok} ->
            wf:update(PanelId, io_lib:format("Story ~p Created", [Value]))
            , wf:insert_top(?SPANELID, #story{story_name=Value});
        _ ->
            throw({error, unknown})
    end
    , ok;
event(Event) -> 
    io:format("recieved unknown event: ~p~n", [Event]),
    ok
.

