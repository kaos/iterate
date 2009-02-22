-module(iterate_db).

-export([start/0, stop/0, setup/0]).
-export([bootstrap/0, info/0, info/1]).
-export([backlogs/0, stories/1]).
-export([backlog/1, story/1]).

-include("macros.hrl").
-include("iterate_records.hrl").
-include_lib("stdlib/include/qlc.hrl").

-define(DEFAULTB, #backlogs{backlog_name="Default", desc="Default backlog"} ).
-define(IDEAPOOL, #backlogs{backlog_name="Idea Pool", desc="Keep track of ideas and brainstorm"} ).

start() ->
    mnesia:start()
.

stop() ->
    mnesia:stop()
.

setup() ->
    stop()
    , mnesia:create_schema([node()])
    , start()
    , mk_table(backlogs, record_info(fields, backlogs))
    , mk_table(stories, record_info(fields, stories))
    , mk_table(time_log, record_info(fields, time_log))
    , bootstrap()
.


bootstrap() ->
   backlog({new, ?DEFAULTB})
  , backlog({new, ?IDEAPOOL})
  , F = fun(B) ->
       fun(N) -> 
           story({new, #stories{backlog=B, story_name=N, sp=3}})
       end
  end
  , lists:foreach(F("Default"), ["story completion"
                               , "story order"
                               , "story time tracking"
                               ]
  )
  , lists:foreach(F("Idea Pool"), ["01 - Reporting"
                                  , "02 - color code stories"
                                  , "03 - backlog types (iteration/staging)"
                                  , "04 - comet updates of the stories and backlogs"
                                  , "06 - tasks for stories"
                                  ]
  )
.

mk_table(Name, Info) ->
    mnesia:create_table(Name, [
        {type, ordered_set}
        , {disc_copies, [node()]}
        , {attributes, Info}
    ])
.

info() ->
    mnesia:system_info()
.

info(Ask) when is_atom(Ask) ->
    mnesia:system_info(Ask)
.

backlogs() ->
    backlog({qry, all})
.

%% TODO(jwall): enforce error when new should be update?
backlog({new, Record}) when is_record(Record, backlogs) ->
    backlog({store, Record});
%% TODO(jwall): should this be smarter?
backlog({update, Record}) when is_record(Record, backlogs) ->
    backlog({store, Record});
%% TODO(jwall): need to update all stories for this backlog also
backlog({mutate, Record, RecordMutation}) when is_record(Record, backlogs) ->
    backlog({delete, Record}),
    Stories = story({qry, Record#backlogs.backlog_name}),
    lists:foreach(fun(Story) -> 
        story({update, Story#stories{backlog=Record#backlogs.backlog_name}})
    end, Stories),
    backlog({new, RecordMutation});
backlog({store, Record}) when is_record(Record, backlogs) ->
    Trans = fun() ->
        mnesia:write(Record)
    end
    , mnesia:transaction(Trans);
backlog({delete, Record}) when is_record(Record, backlogs) ->
    Trans = fun() ->
        %% TODO(jwall): need to move all associated stories to default
        %% TODO(jwall): need to enforce non-delete of Default and Idea Pool
        mnesia:delete({backlogs, Record#backlogs.backlog_name})
    end
    , mnesia:transaction(Trans);
backlog({qry, all}) ->
    Trans = fun() -> mnesia:match_object(#backlogs{_='_'}) end,
    case mnesia:transaction(Trans) of
        {atomic, RecordList} ->
            RecordList;
        {abort, Msg} ->
            {error, Msg};
        _ ->
            {error, "whoah what was that?"}
    end;
backlog({qry, Name}) ->
    Trans = fun() -> mnesia:read({backlogs, Name}) end,
    case mnesia:transaction(Trans) of
        {atomic, RecordList} ->
            RecordList;
        {abort, Msg} ->
            {error, Msg}
    end;
backlog({search, {id, Value}}) ->
    Trans = fun() -> 
        QH = qlc:q([B || B <- 
            mnesia:table(backlogs), string:str(B#backlogs.backlog_name, Value) /= 0]),
        qlc:eval(QH)
    end,
    case mnesia:transaction(Trans) of
        {atomic, RecordList} ->
            RecordList;
        {abort, Msg} ->
            {error, Msg}
    end
.

story({delete, Record}) when is_record(Record, stories) ->
    Trans = fun() ->
        mnesia:delete({stories, Record#stories.story_name})
    end
    , mnesia:transaction(Trans);
story({new, Record}) when is_record(Record, stories) ->
    story({store, Record});
story({update, Record}) when is_record(Record, stories) ->
    story({store, Record});
story({store, Record}) when is_record(Record, stories) ->
    Trans = fun() ->
        case Record#stories.backlog of
            undefined ->
                throw({error, needs_backlog});
            Name ->
                case backlog({qry, Name}) of
                    [] ->
                        throw({error, no_such_backlog});
                    {error, Msg} ->
                        throw({error, Msg});
                     _ ->
                        %% handle the already exists case?
                        mnesia:write(Record)
                end
        end
    end
    , mnesia:transaction(Trans);
story({qry, all}) ->
    Trans = fun() -> mnesia:match_object(#stories{_='_'}) end,
    case mnesia:transaction(Trans) of
        {atomic, RecordList} ->
            RecordList;
        {abort, Msg} ->
            {error, Msg};
        _ ->
            {error, "whoah what was that?"}
    end;
story(?Q_STORY(Name)) ->
    Trans = fun() -> mnesia:read({stories, Name}) end,
    case mnesia:transaction(Trans) of
        {atomic, RecordList} ->
            RecordList;
        {abort, Msg} ->
            {error, Msg}
    end;
story({qry, {backlog, Name}}) ->
    Trans = fun() -> mnesia:match_object(#stories{backlog=Name, _='_'}) end,
    case mnesia:transaction(Trans) of
        {atomic, RecordList} ->
            RecordList;
        {abort, Msg} ->
            {error, Msg};
        _ ->
            throw({error, "whoah what was that?"})
    end
.

stories(B) ->
    story({qry, {backlog, B}})
.

log_time({qry, Story}) ->
    Trans = fun() -> mnesia:read({time_log, Story}) end
    , case mnesia:transaction(Trans) of
        {atomic, [Log]} ->
            Log;
        {atomic, []} ->
            #time_log{story=Story};
        {abort, Msg} ->
            {error, Msg};
        _ ->
            throw({error, "whoah what was that?"})
    end;
log_time({Story, Amount}) ->
    TS = erlang:universaltime()
    , Trans = fun() ->
        Log = log_time({qry, Story})
        , TLog = Log#time_log.t_series
        , mnesia:write(Log#time_log{t_series=[{Amount, TS} | TLog]})
    end
.

