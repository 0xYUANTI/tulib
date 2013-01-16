%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Miscellaneous.
%%% @copyright 2012 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%
%%%   Copyright 2011-2013 Klarna AB
%%%
%%%   Licensed under the Apache License, Version 2.0 (the "License");
%%%   you may not use this file except in compliance with the License.
%%%   You may obtain a copy of the License at
%%%
%%%       http://www.apache.org/licenses/LICENSE-2.0
%%%
%%%   Unless required by applicable law or agreed to in writing, software
%%%   distributed under the License is distributed on an "AS IS" BASIS,
%%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%   See the License for the specific language governing permissions and
%%%   limitations under the License.
%%%

%%%_* Module declaration ===============================================
-module(tulib_util).

%%%_* Exports ==========================================================
-export([ consult_string/1
        , die/1
        , die/2
        , get_arg/3
        , get_arg/4
        , get_env/2
        , get_env/3
        , get_stacktrace/0
        , size/1
        , timestamp/0
        , timestamp/1
        , with_app/2
        , with_env/2
        , with_env/3
        , with_sys/3
        , with_resource/3
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * consult_string --------------------------------------------------
-spec consult_string(string()) -> maybe(term(), _).
%% @doc Parse String as an Erlang term.
consult_string(String) ->
  case erl_scan:string(String ++ ".") of
    {ok, Tokens, _}    -> erl_parse:parse_term(Tokens);
    {error, Info, Loc} -> {error, {Info, Loc}}
  end.

consult_string_test() ->
  {ok, 42}   = consult_string("42"),
  {error, _} = consult_string("{42"),
  {error, _} = consult_string([12345]).

%%%_ * die -------------------------------------------------------------
-spec die(string()) -> no_return().
%% @doc Print a message and halt the emulator.
die(Msg)            -> die(Msg, []).
die(Format, Args)   -> io:format(Format ++ "~n", Args), halt(1).

%%%_ * get_arg, get_env ------------------------------------------------
-spec get_arg(atom(), [_], A) -> A.
%% @doc Get the value associated with Param in either Args or the
%% environment of App. If neither bind Param, return Def.
get_arg(Param, Args, Def) ->
  tulib_lists:assoc(Param, Args, get_env(Param, Def)).
get_arg(Param, Args, Def, App) ->
  tulib_lists:assoc(Param, Args, get_env(Param, Def, App)).

get_arg_test() ->
  App   = tulib_atoms:gensym(app),
  Param = tulib_atoms:gensym(param),
  application:set_env(App, Param, 43),
  42    = get_arg(Param, [{Param, 42}], 44, App),
  43    = get_arg(Param, [], 44, App),
  application:unset_env(App, Param),
  44    = get_arg(Param, [], 44, App),
  ok.

-spec get_env(atom(), A) -> A.
%% @doc Get the value associated with Param in the environment of App.
%% Return Def if Param isn't set. App defaults to the application of
%% the calling process.
get_env(Param, Def) ->
  get_env(Param, Def, application:get_application()).
get_env(Param, Def, App) ->
  case application:get_env(App, Param) of
    {ok, X}   -> X;
    undefined -> Def
  end.

%%%_ * get_stacktrace --------------------------------------------------
-spec get_stacktrace() -> _.
%% @doc Get the trace leading up to the current frame.
get_stacktrace() ->
  get_stacktrace(erlang:get_stacktrace()).
get_stacktrace([]) ->
  try throw(get_stacktrace)
  catch throw:get_stacktrace -> erlang:get_stacktrace()
  end;
get_stacktrace(ST) -> ST.

%%%_ * size ------------------------------------------------------------
-spec size(term()) -> non_neg_integer().
%% @doc Return a lower bound on the heap-size (in bytes) of Term.
size(Term) -> do_size(Term, word_size()) * word_size().

word_size() -> erlang:system_info(wordsize).

do_size(X, Wsize) when is_integer(X)   -> integer_size(X, Wsize);
do_size(X, Wsize) when is_atom(X)      -> atom_size(X, Wsize);
do_size(X, Wsize) when is_float(X)     -> float_size(X, Wsize);
do_size(X, Wsize) when is_binary(X)    -> binary_size(X, Wsize);
do_size(X, Wsize) when is_list(X)      -> list_size(X, Wsize);
do_size(X, Wsize) when is_tuple(X)     -> tuple_size(X, Wsize);
do_size(X, Wsize) when is_pid(X)       -> pid_size(X, Wsize);
do_size(X, Wsize) when is_port(X)      -> port_size(X, Wsize);
do_size(X, Wsize) when is_reference(X) -> reference_size(X, Wsize);
do_size(X, Wsize) when is_function(X)  -> function_size(X, Wsize).

integer_size(X, 4) when -134217729          < X, X < 134217728          -> 1;
integer_size(_, 4)                                                      -> 3;
integer_size(X, 8) when -576460752303423489 < X, X < 576460752303423488 -> 1;
integer_size(_, 8)                                                      -> 3.

atom_size(_, _) -> 1.

float_size(_, 4) -> 4;
float_size(_, 8) -> 3.

binary_size(X, Wsize) -> 3 + ceil(erlang:byte_size(X), Wsize).

ceil(X, Y) ->
  case X rem Y of
    0 -> X div Y;
    _ -> X div Y + 1
  end.

list_size([H|T], Wsize) when not is_list(T) ->
  2 + do_size(H, Wsize) + do_size(T, Wsize);
list_size(Xs, Wsize)  ->
  1 + length(Xs) + elt_size(Xs, Wsize).

tuple_size(Xs, Wsize) -> 2 + elt_size(tuple_to_list(Xs), Wsize).

elt_size(Xs, Wsize) -> lists:sum([do_size(X, Wsize) || X <- Xs]).

pid_size(_, _)       -> 1.
port_size(_, _)      -> 1.
reference_size(_, 4) -> 5;
reference_size(_, 8) -> 4.

function_size(_X, _Wsize) -> 9.


size_test() ->
  Words = (1 + 3) + ((2 + (1 + (1 + 6) + (3 + 1))) + 3 + 1),
  Bytes = Words * word_size(),
  Bytes = ?MODULE:size([{foo, "bar", <<"baz">>}, 42.0, 42]).

%%%_ * timestamp -------------------------------------------------------
-spec timestamp() -> non_neg_integer().
%% @doc Return the number of microseconds passed since the Unix epoch.
timestamp()       -> timestamp(now).
timestamp(now)    -> now_to_microsecs(now());
timestamp(os)     -> now_to_microsecs(os:timestamp()).

now_to_microsecs({MegaSecs, Secs, MicroSecs}) ->
  (1000000 * 1000000 * MegaSecs) + (1000000 * Secs) + MicroSecs.

timestamp_test() -> ?assert(timestamp() < timestamp()).

%%%_ * with_app --------------------------------------------------------
-spec with_app(atom(), fun(() -> A)) -> A.
%% @doc Call Thunk once application App has been started.
with_app(App, Thunk) when is_atom(App) ->
  with_env([App], Thunk);
with_app(Apps, Thunk) when is_list(Apps) ->
  try
    [start_app(App) || App <- Apps],
    Thunk()
  after
    [stop_app(App) || App <- Apps]
  end.

start_app(App) ->
  application:start(App),
  {ok, Regs} = application:get_key(App, registered),
  tulib_processes:sync_registered(Regs),
  ok.

stop_app(App) ->
  case application:get_key(App, registered) of
    {ok, Regs} ->
      application:stop(App),
      tulib_processes:sync_unregistered(Regs);
    undefined ->
      application:stop(App)
  end,
  ok.

%%%_ * with_sys --------------------------------------------------------
-spec with_sys([{atom(), atom(), _}], [atom()], fun(() -> A)) -> A.
%% @doc Call Thunk with application environment Env and started
%% applications Apps.
with_sys(Env, Apps, Thunk) -> with_env(Env, ?thunk(with_app(Apps, Thunk))).

%%%_ * with_env --------------------------------------------------------
-spec with_env(atom(), [{atom(), _}], fun(() -> A)) -> A.
%% @doc Call Thunk with the environment for App set to Env.
with_env(App, Env, Thunk) -> with_env([{App, K, V} || {K, V} <- Env], Thunk).

with_env_test() ->
  undefined = application:get_env(tulib, foo),
  {ok, 42}  = with_env(tulib,
                       [{foo, 42}],
                       ?thunk(application:get_env(tulib, foo))),
  undefined = application:get_env(tulib, foo),
  ok.

-spec with_env([{atom(), _, _}], fun(() -> A)) -> A.
%% @doc Call thunk with the environment set to Env.
with_env(Env, Thunk) ->
  Envs  = parse(normalize(Env)),
  Envs0 = [{App, application:get_all_env(App)} || {App, _} <- Envs],
  try
    setenv(Envs),
    Thunk()
  after
    setenv(Envs0)
  end.

%% Prioritize.
normalize(Env) ->
  lists:usort( %stable
    fun({App, Par, _}, {App, Par, _}) -> true;
       (X,             Y)             -> X < Y
    end, Env).

parse(Envs) ->
  dict:to_list(
    lists:foldl(
      fun({App, K, V}, Dict) ->
        dict:update(App, fun(KVs) -> [{K, V}|KVs] end, [{K, V}], Dict)
      end, dict:new(), Envs)).

setenv(Envs) ->
  [setenv(App, Env) || {App, Env} <- Envs].
setenv(App, Env) ->
  [application:unset_env(App, K)  || {K, _} <- application:get_all_env(App)],
  [application:set_env(App, K, V) || {K, V} <- Env].

%%%_ * with_resource ---------------------------------------------------
-spec with_resource(fun(), fun(), fun()) -> _.
%% @doc Call Setup, then Thunk, then Cleanup.
with_resource(Setup, Cleanup, Thunk) ->
  try Setup(), Thunk()
  after Cleanup()
  end.

with_resource_test() ->
  F = fun() -> ok end,
  with_resource(F, F, F).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
