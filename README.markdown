# ejabberd-mod-mam

**ejabberd-mod-mam** is a module for the ejabberd XMPP server that implements
the "Message Archive Management" functionality [XEP-0313][xep] using a
[MongoDB][mongo] backend.

The module targets the so-called "Community Edition" of *ejabberd* that can be
found on the current [master][master] branch of the ejabberd
[repository][master] on github.

> ejabberd-mod-mam is a work in progress and currently to be considered beta


## Requirements

* ejabberd community edition
* >= erlang R16B01
* mongodb erlang driver ([repository][driver]) and its dependencies


## Install

As of now there is no ready-to-use build/install script for the module.
Basically all you have to do is to add the MongoDB erlang driver to the
ejabberd rebar script and copy/link the `mod_mam.erl` into the `src` directory
of ejabberd.


## Configuration

In order to use **mod-mam** you have to add it to the modules section in your
`ejabberd.cfg`. This could look like this:

``` erlang
{modules,
  [
    {mod_mam,
      [
        % use the default localhost:27017
        % or define a specific host
        {mongo, {localhost, 27017}},

        % define a database to use
        % (default: test)
        {mongo_database, test},

        % specify a collection to use
        % (default: ejabberd_mam)
        {mongo_collection, ejabberd_mam}
      ]
    },

    % ...
  ]
}.
```


### Replica sets

You may use MongoDB replica set connections as well:


``` erlang
{modules,
  [
    {mod_mam,
      [
        % configure a named replica set and a list of nodes
        {mongo, {<<"rs">>, [{localhost, 27017}, {localhost, 27018}]}},

        % ...
      ]
    },

    % ...
  ]
}.

```


## MongoDB

The messages that are stored as BSON documents in the MongoDB look like the
following:

``` json
{
    "_id" : ObjectId("531f6f25cdbb08145f000001"),
    "u" : "test2",
    "s" : "localhost",
    "j" : {
        "u" : "test",
        "s" : "localhost",
        "r" : "sendxmpp"
    },
    "b" : "foo bar",
    "d" : "to",
    "ts" : ISODate("2014-03-11T20:16:37.772Z"),
    "r" : "<message xml:lang='en' to='test@localhost/sendxmpp' type='chat'><body>foo bar</body><subject/></message>"
}
```


## TODO

* fully implement RSM (XEP-0059)
* ejabberd fork/branch with integrated mod\_mam
* archiving preferences
* tests


## Maintainer

*ejabberd-mod-mam* is written by Gregor Uhlenheuer. You can reach me at
<kongo2002@gmail.com>.


[xep]: http://xmpp.org/extensions/xep-0313.html
[mongo]: http://mongodb.org
[master]: https://github.com/processone/ejabberd/tree/master
[driver]: https://github.com/mongodb/mongodb-erlang/tree/master
