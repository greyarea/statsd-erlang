-module(statsd).
-author("Dominik Liebler").
-behaviour(gen_server).

%% forced by gen_server
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start/2, start/1, start/0, stop/0]).
-export([increment/1, increment/2, decrement/1, decrement/2, count/2, count/3, gauge/2, timing/2, timing/3]).

-define(STATSD_DEFAULT_PORT, 8125).
-define(STATSD_DEFAULT_HOST, "localhost").

%% holds all the relevant state that is used internally to pass the socket around
-record(state, {
	port = ?STATSD_DEFAULT_PORT,
	host = ?STATSD_DEFAULT_HOST,
	socket
}).

%% Public: opens the socket
%%
%% returns a #state record containing the socket
-spec start(string(), non_neg_integer()) -> #state{}.
start(Host, Port) ->
	{ok, Socket} = gen_udp:open(0),
	State = #state{port = Port, host = Host, socket = Socket},
	gen_server:start_link({local, ?MODULE}, ?MODULE, [State], []).

-spec start(string()) -> #state{}.
start(Host) ->
	start(Host, ?STATSD_DEFAULT_PORT).

-spec start() -> #state{}.
start() ->
	start(?STATSD_DEFAULT_HOST).

%% Public: stop server
%%
%% returns: {ok}
-spec stop() -> {ok}.
stop() ->
	gen_server:call(?MODULE, stop),
	{ok}.

%% Internal: used by gen_server and called on connection init
%%
%% returns: {ok, State}
-spec init([term()]) -> {ok, term()}.
init([State]) ->
	{ok, State}.

%% Internal: used by gen_server and called on connection termination
%%
%% returns: {ok}
-spec terminate(term(), term()) -> {ok, term()}.
terminate(_Reason, State) ->
	{ok, State}.
	
%% Public: increments a counter by 1
%% 
%% returns ok or {error, Reason}
-spec increment(string(), number()) -> ok | {error, term()}.
increment(Key, Samplerate) ->
	count(Key, 1, Samplerate).

-spec increment(string()) -> ok | {error, term()}.
increment(Key) ->
	count(Key, 1).
	
%% Public: decrements a counter by 1
%% 
%% returns ok or {error, Reason}
-spec decrement(string(), number()) -> ok | {error, term()}.
decrement(Key, Samplerate) ->
	count(Key, -1, Samplerate).

-spec decrement(string()) -> ok | {error, term()}.
decrement(Key) ->
	count(Key, -1).

%% Public: increments a counter by an arbitrary integer value
%%
%% returns: ok or {error, Reason}
-spec count(string(), integer()) -> ok | {error, term()}.
count(Key, Value) ->
	send({message, Key, Value, c}).

-spec count(string(), integer(), number()) -> ok | {error, term()}.
count(Key, Value, Samplerate) ->
	send({message, Key, Value, c, Samplerate}, Samplerate).

%% Public: sends an arbitrary gauge value
%%
%% returns: ok or {error, Reason}
-spec gauge(string(), number()) -> ok | {error, term()}.
gauge(Key, Value) ->
	send({message, Key, Value, g}).

%% Public: sends a timing in ms
%%
%% returns: ok or {error, Reason}
-spec timing(string(), number()) -> ok | {error, term()}.
timing(Key, Value) ->
	send({message, Key, Value, ms}).

-spec timing(string(), number(), number()) -> ok | {error, term()}.
timing(Key, Value, Samplerate) ->
	send({message, Key, Value, ms, Samplerate}, Samplerate).
	
%% Internal: prepares and sends the messages
%%
%% returns: ok or {error, Reason}
send(Message, Samplerate) when Samplerate =:= 1 ->
    send(Message);

send(Message, Samplerate) ->
    case random:uniform() =< Samplerate of
        true -> send(Message);
        _ -> ok
    end.

send(Message) ->
    gen_server:call(?MODULE, {send_message, build_message(Message)}).

%% Internal: builds the message string to be sent
%% 
%% returns: a String
build_message({message, Key, Value, Type}) ->
	lists:concat([Key, ":", io_lib:format("~w", [Value]), "|", Type]);
build_message({message, Key, Value, Type, Samplerate}) ->
	lists:concat([build_message({message, Key, Value, Type}) | ["@", io_lib:format("~.2f", [1.0 / Samplerate])]]).

%% Internal: handles gen_server:call calls
%%
%% returns:	{reply, ok|error, State}
-spec handle_call({atom(), term()} | atom(), term(), term()) -> {reply, ok | error, term()}.
handle_call({send_message, Message}, _From, State) ->
	gen_udp:send(State#state.socket, State#state.host, State#state.port, Message),
	{reply, ok, State};
handle_call(stop, _From, State) ->
	gen_udp:close(State#state.socket),
	{stop, normal, stopped, State}.

-spec code_change(term(), term(), term()) -> {ok, term()}.
code_change(_OldVersion, State, _Extra) -> {ok, State}.

-spec handle_cast(term(), term()) -> {ok, term()}.
handle_cast(_Message, State) -> {ok, State}.

-spec handle_info(term(), term()) -> {ok, term()}.
handle_info(_Info, State) -> {ok, State}.
