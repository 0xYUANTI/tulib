%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Composable error handling.
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
-module(tulib_maybe).

%%%_* Exports ==========================================================
%% Primitives
-export([ lift/1
        , lift/2
        , unlift/1
        ]).

%% Single-step evaluation
-export([ cps/3
        , lift_with/2
        , lift_with/3
        ]).

%% Multi-step evaluation
-export([ do/1
        , map/2
        , reduce/2
        , reduce/3
        , '-?>'/2
        , '-?>>'/2
        ]).

%% Values
-export([ partition/1
        , to_bool/1
        , untag/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").
-include_lib("tulib/include/prelude.hrl").
-include_lib("tulib/include/types.hrl").

%%%_* Code =============================================================
%%%_ * Primitives ------------------------------------------------------
-spec lift(fun()) -> maybe(_, _).
%% @doc Ensure that the result of F, which must be a thunk, is in
%% maybe().
lift(F) ->
  try F() of
    ok                  -> {ok, ok};
    {ok, Res}           -> {ok, Res};
    error               -> {error, error};
    {error, Rsn}        -> {error, Rsn};
    Res                 -> {ok, Res}
  catch
    throw:{error, Rsn}  -> {error, Rsn};
    _:Exn               -> {error, {lifted_exn, Exn, erlang:get_stacktrace()}}
  end.

-spec unlift(fun()) -> _.
%% @doc Ensure that the result of F, which must be a thunk, is not in
%% maybe().
unlift(F) ->
  case F() of
    ok           -> ok;
    {ok, Res}    -> Res;
    error        -> throw({error, error});
    {error, Rsn} -> throw({error, Rsn});
    Res          -> Res
  end.

lift_unlift_test() ->
  42             = ?unlift(?lift(?unlift(42))),
  {error, 42}    = ?lift(?unlift({error, 42})),
  ok             = ?unlift(?lift(ok)),
  {error, error} = (catch ?unlift(?lift(error))),
  ok             = ?unlift(ok),
  ok.


-spec lift(fun(), fun()) -> maybe(_, _).
%% @doc Lift F into maybe(); unwind via G.
lift(F, G) ->
  try lift(F)
  after G()
  end.

%%%_ * Single-step evaluation ------------------------------------------
%%%_  * CPS ------------------------------------------------------------
-spec cps(fun(), Succ::fun(), Fail::fun()) -> maybe(_, _).
%% @doc Lift Thunk into maybe(), then apply Ok or Error to the resulting
%% value.
cps(Thunk, Ok, Error) ->
  case lift(Thunk) of
    {ok, Res}    -> ?lift(Ok(Res));
    {error, Rsn} -> ?lift(Error(Rsn))
  end.

cps_test() ->
  I              = fun tulib_combinators:i/1,
  Thunk1         = fun() -> ok    end,
  Thunk2         = fun() -> error end,
  {ok, ok}       = cps(Thunk1, I, I),
  {error, error} = cps(Thunk2, I, I),
  ok.

%%%_  * lift_with ------------------------------------------------------
-spec lift_with(_, fun())       -> maybe(_, _).
%% @doc Apply F to X and lift the result into maybe().
lift_with({error, _} = Err, _F) -> Err;
lift_with(error, _F)            -> {error, error};
lift_with({ok, X}, F)           -> lift(?thunk(F(X)));
lift_with(ok, F)                -> lift(F);
lift_with(X, F)                 -> lift(?thunk(F(X))).

lift_with2_test() ->
  {error, error} = lift_with(error, fun(X) -> X end),
  {error, 42}    = lift_with({error, 42}, fun(X) -> X end),
  {ok, ok}       = lift_with(ok, fun() -> ok end),
  {ok, 42}       = lift_with(42, fun(X) -> X end),
  ok.


-spec lift_with(_, fun(), fun())    -> maybe(_, _).
%% @doc Apply F to X and lift the result into maybe(); unwind via G(X).
lift_with({error, _} = Err, _F, _G) -> Err;
lift_with(error, _F, _G)            -> {error, error};
lift_with({ok, X}, F, G)            -> lift(?thunk(F(X)), ?thunk(G(X)));
lift_with(ok, F, G)                 -> lift(F, G);
lift_with(X, F, G)                  -> lift(?thunk(F(X)), ?thunk(G(X))).

lift_with3_test() ->
  {error, error} = lift_with(error, fun(X) -> X end, fun(_) -> ok end),
  {ok, ok}       = lift_with(ok,
                             fun() -> ok end,
                             fun() -> ok end),
  ok.

%%%_ * Multi-step evaluation -------------------------------------------
%%%_  * do -------------------------------------------------------------
-spec do([fun()]) -> maybe(_, _).
%% @doc Call the functions Fs in sequence until either one of them fails
%% (in which case that error is returned) or all of them have been
%% executed (in which case the return value of the last function becomes
%% the return value of the `do' expression).
do([F])    -> lift(F);
do([F|Fs]) -> case lift(F) of
                {ok, _}          -> do(Fs);
                {error, _} = Err -> Err
              end.

do_test() ->
  {error, foo} = do([ fun() -> {error, foo} end
                    , fun() -> ok end
                    ]),
  {ok, ok}     = do([ fun() -> 42 end
                    , fun() -> ok end
                    ]),
  ok.

%%%_  * Map/reduce -----------------------------------------------------
-spec map(fun(), [_]) -> maybe(_, _).
%% @doc Map F over Xs and lift the result into maybe().
map(F, Xs) -> ?lift([?unlift(F(X)) || X <- Xs]).

map_test() ->
  {ok, [2, 4, 6]} = map(fun(X) -> 2 * X       end, [1, 2, 3]),
  {ok, [2, 4, 6]} = map(fun(X) -> {ok, 2 * X} end, [1, 2, 3]),
  {error, _}      = map(fun(X) -> {ok, 2 * X} end, [1, foo, 3]).


-spec reduce(fun(), [_]) -> maybe(_, _).
%% @doc Reduce F into Xs and lift the result into maybe().
reduce(F, [Acc0|Xs]) ->
  ?lift(lists:foldl(fun(X, Acc) -> ?unlift(F(X, Acc)) end, Acc0, Xs)).

-spec reduce(fun(), _, [_]) -> maybe(_, _).
reduce(F, Acc0, Xs) ->
  ?lift(lists:foldl(fun(X, Acc) -> ?unlift(F(X, Acc)) end, Acc0, Xs)).

reduce_test() ->
  {ok, 6}        = reduce(fun(A, B) -> A + B       end, [1, 2, 3]),
  {ok, 6}        = reduce(fun(A, B) -> {ok, A + B} end, [1, 2, 3]),
  {error, error} = reduce(fun(_, _) -> error       end, [1, 2, 3]).

%%%_  * Clojure --------------------------------------------------------
-spec '-?>'(_, [{fun(), [_]} | mfa() | fun()]) -> maybe(_, _).
%% @doc Thread X through Fs, as the first argument.
'-?>'(X, Fs) ->
  reduce(
    fun({F, A},    Acc)                        -> apply(F, [Acc|A]);
       ({M, F, A}, Acc)                        -> apply(M, F, [Acc|A]);
       (F,         Acc) when is_function(F, 1) -> F(Acc)
    end, X, Fs).

'-?>_test'() ->
  {ok, 86} =
    '-?>'(42,
      [ fun(X)     -> X     end
      , {fun(X, Y) -> X + Y end, [1]}
      , fun(X)     -> X * 2 end
      ]),
  {error, {lifted_exn, meh, _}} =
    '-?>'(0,
      [ fun(X)     -> X          end
      , {fun(X, Y) -> X/Y        end, [1]}
      , fun(_)     -> throw(meh) end
      ]),
  {error, {lifted_exn, badarith, _}} =
    '-?>'(0,
      [ fun(X)     -> X          end
      , {fun(X, Y) -> Y/X        end, [1]}
      , fun(_)     -> throw(meh) end
      ]),
  ok.


-spec '-?>>'(_, [{fun(), [_]} | mfa() | fun()]) -> maybe(_, _).
%% @doc Thread X through Fs, as the last argument.
'-?>>'(X, Fs) ->
  reduce(
    fun({F, A},    Acc)                        -> apply(F, A ++ [Acc]);
       ({M, F, A}, Acc)                        -> apply(M, F, A ++ [Acc]);
       (F,         Acc) when is_function(F, 1) -> F(Acc)
    end, X, Fs).

'-?>>_test'() ->
  {ok, 86} =
    '-?>>'(42,
      [ fun(X)     -> X     end
      , {fun(X, Y) -> X + Y end, [1]}
      , fun(X)     -> X * 2 end
      ]),
  {error, {lifted_exn, badarith, _}} =
    '-?>>'(0,
      [ fun(X)     -> X          end
      , {fun(X, Y) -> X/Y        end, [1]}
      , fun(_)     -> throw(meh) end
      ]),
  {error, {lifted_exn, meh, _}} =
    '-?>>'(0,
      [ fun(X)     -> X          end
      , {fun(X, Y) -> Y/X        end, [1]}
      , fun(_)     -> throw(meh) end
      ]),
  ok.

%%%_ * Values ----------------------------------------------------------
-spec partition([maybe(A, B)]) -> {[A], [B]}.
%% @doc Partition a list of values in maybe() into a list of results and
%% a list of reasons
partition(Rets) ->
  {Oks, Errs} = lists:partition(fun to_bool/1, Rets),
  Untag       = fun({_F, S}) -> S end,
  {lists:map(Untag, Oks), lists:map(Untag, Errs)}.

partition_test() ->
  {[foo, bar], [baz, quux]} =
    partition([{ok, foo}, {ok, bar}, {error, baz}, {error, quux}]).


-spec to_bool(maybe(_, _)) -> boolean().
%% @doc Interpret a value in maybe() as a value in boolean().
to_bool({ok, _})           -> true;
to_bool({error, _})        -> false.

to_bool_test() ->
  true  = to_bool({ok, 42}),
  false = to_bool({error, 42}).


-spec untag(maybe(_, _)) -> _ | no_return().
%% @doc Convert a value in maybe() into a term or an exception.
untag({ok, Res})         -> Res;
untag({error, _} = Err)  -> throw(Err).

untag_test() ->
  42          = untag({ok, 42}),
  {error, 42} = (catch untag({error, 42})).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
