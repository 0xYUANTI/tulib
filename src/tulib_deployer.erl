%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Automagically deploy local changes on remote nodes.
%%% @reference https://github.com/mochi/mochiweb/blob/master/src/reloader.erl
%%% @copyright 2007 Mochi Media, Inc.
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%_* Module declaration ===============================================
-module(tulib_deployer).
-behaviour(gen_server).

%%%_* Exports ==========================================================
-export([ start/0
        , start/1
        , stop/0
        ]).

-export([ load/1 %RPC
        ]).

-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").
-include_lib("tulib/include/guards.hrl").
-include_lib("tulib/include/prelude.hrl").

%%%_* Macros ===========================================================
-define(SERVER, ?MODULE).

%%%_* Code =============================================================
%%%_ * API -------------------------------------------------------------
start()      -> start(nodes()).
start(Nodes) -> gen_server:start({local, ?SERVER}, ?MODULE, Nodes, []).
stop()       -> gen_server:cast(?SERVER, stop).

%%%_ * gen_server callbacks --------------------------------------------
-record(s, { nodes :: [node()]
           , timer :: _
           , ts    :: tuple()
           }).

code_change(_, S, _) -> {ok, S}.

init(Nodes) ->
  {ok, Timer} = timer:send_interval(timer:seconds(5), tick),
  {ok, #s{nodes=Nodes, timer=Timer, ts=timestamp()}}.

terminate(_, #s{timer=Timer}) -> {ok, cancel} = timer:cancel(Timer), ok.

handle_call(_, _, S) -> {stop, bad_call, S}.
handle_cast(stop, S) -> {stop, normal,   S}.

handle_info(tick, #s{nodes=Nodes, ts=LocalTime} = S) ->
  tulib_processes:flush(tick),
  distribute(Nodes, generated_since(LocalTime)),
  {noreply, S#s{ts=timestamp()}};
handle_info(_, S) ->
  {stop, bad_info, S}.

%%%_ * Internals -------------------------------------------------------
timestamp() -> erlang:localtime().

generated_since(LocalTime) ->
  [begin
     {Mod, Beam, File} = code:get_object_code(Mod),
     {Mod, Beam}
   end || {Mod, File} <- code:all_loaded(),
          ?is_string(File),
          generated_since(File, LocalTime)].

generated_since(File, LocalTime) ->
  {ok, #file_info{mtime=Mtime}} = file:read_file_info(File),
  Mtime > LocalTime.

distribute(Nodes, TaggedBeams) ->
  {_, []} = rpc:multicall(Nodes,
                          ?MODULE,
                          load,
                          TaggedBeams,
                          timer:seconds(1)),
  ok.

load({Mod, Beam}) ->
  {file, File}  = code:is_loaded(Mod),
  {module, Mod} = code:load_binary(Mod, File, Beam),
  ok.

%%%_* Tests ============================================================
-ifdef(TEST).

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
