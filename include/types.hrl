%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Common type definitions.
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

-ifndef(__TYPES_HRL).
-define(__TYPES_HRL, true).

%% Return values
-type ok(A)       :: {ok, A}.
-type error(A)    :: {error, A}.
-type maybe(A, B) :: {ok, A} | {error, B}.
-type whynot()    :: ok | {error, _}.

%% Misc
-type alist(A, B) :: [{A, B}].
-type file()      :: string().

-endif. %include guard

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
