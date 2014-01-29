-module(mod_mam).
-author('kongo2002@googlemail.com').

-behaviour(gen_server).
-behaviour(gen_mod).


-include("ejabberd.hrl").
-include("logger.hrl").
-include("jlib.hrl").


%% API
-export([start_link/2,
         start/2,
         stop/1,
         remove_user/2,
         send_packet/3,
         receive_packet/4
         % process_iq/3,
         % process_local_iq/3,
         % get_disco_features/5
        ]).


%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(PROCNAME, ejabberd_mod_mam).
-define(POOL_SIZE, 10).

-record(state, {host = <<"">>        :: binary(),
                ignore_chats = false :: boolean(),
                pool}).


%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Host, Opts) ->
    Proc = get_proc(Host),
    gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts], []).

start(Host, Opts) ->
    Proc = get_proc(Host),

    application:ensure_started(bson),
    application:ensure_started(mongodb),

    Child =
        {Proc,
         {?MODULE, start_link, [Host, Opts]},
         temporary,
         1000,
         worker,
         [?MODULE]},

    supervisor:start_child(ejabberd_sup, Child).

stop(Host) ->
    Proc = get_proc(Host),
    gen_server:call(Proc, stop),
    supervisor:terminate_child(ejabberd_sup, Proc),
    supervisor:delete_child(ejabberd_sup, Proc).

send_packet(From, To, Packet) ->
    Host = From#jid.lserver,
    Proc = get_proc(Host),
    gen_server:cast(Proc, {log, to, From#jid.luser, Host, To, Packet}).

receive_packet(_Jid, From, To, Packet) ->
    Host = To#jid.lserver,
    Proc = get_proc(Host),
    gen_server:cast(Proc, {log, from, To#jid.luser, Host, From, Packet}).

remove_user(User, Server) ->
    LUser = jlib:nodeprep(User),
    LServer = jlib:nameprep(Server),
    US = {LUser, LServer},
    % TODO: remove from mongo

    ok.


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Host, Opts]) ->
    % todo: disco

    ?INFO_MSG("Starting mod_mam module of ~p", [Host]),

    IgnoreChats = gen_mod:get_opt(ignore_chats, Opts, false, false),
    MongoConn = gen_mod:get_opt(mongo, Opts,
                                fun ({H, P}) -> {H, P} end,
                                {localhost, 27017}),

    % hook into send/receive packet
    ejabberd_hooks:add(user_send_packet, Host, ?MODULE, send_packet, 80),
    ejabberd_hooks:add(user_receive_packet, Host, ?MODULE, receive_packet, 80),

    % hook into user removal
    ejabberd_hooks:add(remove_user, Host, ?MODULE, remove_user, 50),

    MPool = resource_pool:new(mongo:connect_factory(MongoConn), ?POOL_SIZE),

    {ok, #state{host = Host,
                ignore_chats = IgnoreChats,
                pool = MPool}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({log, Dir, LUser, LServer, Jid, Packet}, State) ->
    ?INFO_MSG("Packet: ~p", [Packet]),
    case should_store(LUser, LServer) of
        true ->
            IgnoreChats = State#state.ignore_chats,
            case extract_body(Packet, IgnoreChats) of
                ignore -> ok;
                Body ->
                    Pool = State#state.pool,
                    Doc = get_message(Dir, LUser, LServer, Jid, Body),
                    insert(Pool, Doc)
            end;
        false -> ok
    end,

    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, State) ->
    Host = State#state.host,
    Pool = State#state.pool,

    ?INFO_MSG("Stopping mod_mam module of ~p", [Host]),

    ejabberd_hooks:delete(user_send_packet, Host, ?MODULE, send_packet, 80),
    ejabberd_hooks:delete(user_receive_packet, Host, ?MODULE, receive_packet, 80),

    ejabberd_hooks:delete(remove_user, Host, ?MODULE, remove_user, 50),

    resource_pool:close(Pool),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

should_store(User, Server) ->
    % TODO
    true.

extract_body(#xmlel{name = <<"message">>} = Xml, IgnoreChats) ->
    % archive messages with a body tag only
    case xml:get_subtag(Xml, <<"body">>) of
        false -> ignore;
        Body ->
            case IgnoreChats of
                true ->
                    % do not archive groupchat messages
                    case xml:get_tag_attr(<<"type">>, Xml) of
                        {value, <<"groupchat">>} -> ignore;
                        _ -> xml:get_tag_cdata(Body)
                    end;
                _ -> xml:get_tag_cdata(Body)
            end
    end;

extract_body(_, _) -> ignore.

get_proc(Host) ->
    gen_mod:get_module_proc(Host, ?PROCNAME).

%%%-------------------------------------------------------------------
%%% MongoDB functions
%%%-------------------------------------------------------------------

get_message(Dir, LUser, LServer, Jid, Body) ->
    bson:document([
                   {user, LUser},
                   {server, LServer},
                   {jid, Jid},
                   {body, Body},
                   {direction, Dir},
                   {ts, bson:timenow()}
                  ]).

insert(Pool, Element) ->
    Fun = fun () -> mongo:insert(messages, Element) end,
    exec(Pool, Fun).

exec(Pool, Function) ->
    case resource_pool:get(Pool) of
        {ok, Conn} ->
            case mongo:do(safe, slave_ok, Conn, test, Function) of
                {ok, {}} -> none;
                {ok, {Found}} -> Found;
                {ok, Cursor} -> Cursor
            end;
        {error, _Reason} -> false
    end.


% vim: set et sw=4 sts=4 tw=80:
