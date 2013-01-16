%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Preprocessor prelude.
%%% @copyright 2011 Klarna AB
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

-ifndef(__PRELUDE_HRL).
-define(__PRELUDE_HRL, true).

-define(a2l, erlang:atom_to_list).
-define(l2a, erlang:list_to_atom).
-define(b2l, erlang:binary_to_list).
-define(l2b, erlang:list_to_binary).
-define(b2t, erlang:binary_to_term).
-define(t2b, erlang:term_to_binary).
-define(i2l, erlang:integer_to_list).
-define(l2i, erlang:list_to_integer).
-define(l2t, erlang:list_to_tuple).
-define(t2l, erlang:tuple_to_list).


%% Font-lock
-define(Q,  $\'). %'
-define(QQ, $\"). %"


-define(call(F),    erlang:apply(?MODULE, F, [])).
-define(call(F, A), erlang:apply(?MODULE, F, A)).


-define(lift(Expr),           tulib_maybe:lift(fun() -> Expr end)).
-define(unlift(Expr),         tulib_maybe:unlift(fun() -> Expr end)).
-define(lift_with(Expr, Fun), tulib_maybe:lift_with(?lift(Expr), Fun)).


-define(thunk(E0),
        fun() -> E0 end).
-define(thunk(E0, E1),
        fun() -> E0, E1 end).
-define(thunk(E0, E1, E2),
        fun() -> E0, E1, E2 end).
-define(thunk(E0, E1, E2, E3),
        fun() -> E0, E1, E2, E3 end).
-define(thunk(E0, E1, E2, E3, E4),
        fun() -> E0, E1, E2, E3, E4 end).
-define(thunk(E0, E1, E2, E3, E4, E5),
        fun() -> E0, E1, E2, E3, E4, E5 end).
-define(thunk(E0, E1, E2, E3, E4, E5, E6),
        fun() -> E0, E1, E2, E3, E4, E5, E6 end).
-define(thunk(E0, E1, E2, E3, E4, E5, E6, E7),
        fun() -> E0, E1, E2, E3, E4, E5, E6, E7 end).
-define(thunk(E0, E1, E2, E3, E4, E5, E6, E7, E8),
        fun() -> E0, E1, E2, E3, E4, E5, E6, E7, E8 end).
-define(thunk(E0, E1, E2, E3, E4, E5, E6, E7, E8, E9),
        fun() -> E0, E1, E2, E3, E4, E5, E6, E7, E8, E9 end).


%% Luke Gorrie's favourite profiling macro.
-define(TIME(Tag, Expr),
        (fun() ->
           %% NOTE: timer:tc/4 does an annoying 'catch' so we
           %% need to wrap the result in 'ok' to be able to
           %% detect an unhandled exception.
           {__TIME, __RESULT} =
             timer:tc(erlang, apply, [fun() -> {ok, Expr} end, []]),
           io:format("time(~s): ~18.3fms ~999p~n",
                     [?MODULE, __TIME/1000, Tag]),
           case __RESULT of
             {ok, _}         -> element(2, __RESULT);
             {'EXIT', Error} -> exit(Error)
           end
         end)()).

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
