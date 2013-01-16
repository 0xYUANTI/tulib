%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Assertion-macros.
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

-ifndef(__ASSERT_HRL).
-define(__ASSERT_HRL, true).

-define(hence(A),
        (case A of
           true -> ok;
           _    -> throw({error, {assert, {??A,'=',true}, ?FILE, ?LINE}})
         end)).

-define(given(A, B),
        (case ((not (A)) orelse (B)) of
           true -> ok;
           _    -> throw({error, {assert, {??A,'->',??B}, ?FILE, ?LINE}})
         end)).

-define(match(A, B),
        (case B of
           A -> ok;
           _ -> throw({error, {assert, {??A,'=',??B}, ?FILE, ?LINE}})
         end)).

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
