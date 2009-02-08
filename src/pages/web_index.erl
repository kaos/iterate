-module (web_index).
-include_lib ("nitrogen/include/wf.inc").
-include("../elements.hrl").
-compile(export_all).

%%TODO(jwall): move the following into the main index page
main() ->
	#template { file="./wwwroot/template.html"}.

title() ->
	"Iterate<i>!</i>".

body() ->
    #panel{ id=main, body=[
        #hr{}
        , body(contents)
    ]}.

body(contents) ->
    #singlerow{ id=main, cells=[
	    #tablecell{ body=[backlog_panel()] },
        #tablecell{ body=[story_panel()] }
    ]}.

backlog_panel() ->
    #backlog_panel{data=iterate_db:backlogs()}.

story_panel() ->
    #story_panel{ data=["click a backlog to see stories"] }.

story(Name) ->
    #listitem{ id=Name,
        body=#story{story_name=Name}
    }.

%% TODO(jwall): move events into a different module perhaps element modules?
%% showing stories
event({show, {stories, Name}}) ->
    wf:update(story_list, [story(SName) || SName <- iterate_db:stories(Name)]);
event(_) -> ok.
