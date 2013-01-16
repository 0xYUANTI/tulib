%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Test include/
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

-module(macro_tests).
-export([ assert_test/0
        ]).
-include_lib("tulib/include/assert.hrl").
-include_lib("tulib/include/prelude.hrl").

assert_test() ->
  ok                         = ?hence(1=:=1),
  {error, {assert, _, _, _}} = ?lift(?hence(1=:=2)),
  ok                         = ?given(1=:=1, 2=:=2),
  ok                         = ?given(1=:=2, 2=:=3),
  {error, {assert, _, _, _}} = ?lift(?given(1=:=1, 2=:=3)),
  ok                         = ?match(foo, foo),
  {error, {assert, _, _, _}} = ?lift(?match(foo, bar)),
  ok.

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
