-module(statsd_app).
-author("Martin Donath").
-behaviour(application).

-export([start/2, stop/1]).

%% Public: starts the statsd server
%%
%% returns a #state record containing the socket
-spec start(normal | {takeover, node()} | {failover, node()}, term()) -> {ok, pid()}.
start(_Type, Args) ->
  erlang:apply(statsd, start, Args).

%% Public: stops the statsd server
%%
%% returns ok
-spec stop(term()) -> ok.
stop(_State) ->
  ok.
