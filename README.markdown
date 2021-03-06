# ejabberd-mod-mam

**ejabberd-mod-mam** is a module for the ejabberd XMPP server that implements
the "Message Archive Management" functionality [XEP-0313][xep] using a
[MongoDB][mongo] backend.

The module targets the so-called "Community Edition" of *ejabberd* that can be
found on the current [master][master] branch of the ejabberd
[repository][master] on github.

> ejabberd-mod-mam is a work in progress and currently to be considered beta


## XEP-0313

I recently noticed that the XEP-0313 was updated to *Version 3* that basically
changed all of the query and result syntax. As of now **this module still
targets the Version 2** of the XEP-0313.


## Requirements

* ejabberd community edition
* >= erlang R16B01
* mongodb erlang driver ([repository][driver]) and its dependencies

Since the *MongoDB erlang driver* changed the maintainer and received various
API changes while reducing some of its features (i.e. support for replica sets)
this module still uses the *old* version of the MongoDB driver meaning the
commit tagged with `v0.3.1`.


## Install

In order to get going basically all you have to do is to add the MongoDB erlang
driver to the ejabberd rebar script. Then you copy/link the `mod_mam.erl` into
the `src` directory of ejabberd prior to compiling ejabberd itself.

Otherwise you may use my [mod\_mam][mam-ejabberd] branch of the forked official
ejabberd master branch. This branch is obviously not always *in-sync* with the
current ejabberd development but my changes may be sufficient to give an idea
how to add **mod\_mam** to your ejabberd compile process:

``` bash
$ git clone git://github.com/kongo2002/ejabberd.git
$ cd ejabberd
$ git checkout origin/mod_mam -b mod_mam
$ ./configure --enable-mongodb
$ make
```


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

Using the new [YAML][yaml] format the same configuration would look like the
following:

``` yaml
modules:
  mod_mam:
    mongo:
      localhost: 27017
    mongo_database: test
    mongo_collection: messages
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

The [YAML][yaml] equivalent looks like this:

``` yaml
modules:
  mod_mam:
    mongo:
      "rs":
        localhost: 27017
        localhost: 27018
```


## MongoDB

The messages that are stored as BSON documents in the MongoDB look like the
following:

``` javascript
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
* archiving preferences
* tests


## Maintainer

*ejabberd-mod-mam* is written by Gregor Uhlenheuer. You can reach me at
<kongo2002@gmail.com>.


[xep]: http://xmpp.org/extensions/xep-0313.html
[mongo]: http://mongodb.org
[master]: https://github.com/processone/ejabberd/tree/master
[driver]: https://github.com/comtihon/mongodb-erlang/tree/master
[mam-ejabberd]: https://github.com/kongo2002/ejabberd/tree/mod_mam
[yaml]: http://www.yaml.org/
