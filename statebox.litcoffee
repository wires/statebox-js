This is the statebox system.

Lets import some basics

    Q = require 'kew'
    _ = require 'lodash'

We are going to be doing async http using promises, `mach` is a
fitting http server for this.

    mach = require 'mach'
    app = mach.stack()

    app.use mach.logger
    app.use mach.params

Let's setup a route for sign of life.

    app.get '/ping', () ->
        "pong"

First we need to add processes to the system.

# The Processing Model

## Describing a process

We define a process a follows.

any of the following is allowed

    # specify nr of places, identifiers are integers
    places: 2

    # specify named identifiers (strings)
    places: ['a','b']

    # a 'place description' is just a dictionary
    p0 = { capacity: 1 }

    # it can also be the empty object
    p1 = {}

    # array of unamed place descriptions
    # transition.pre/post identifiers must be integers
    places: [ p0, p1 ]

    # dictionary of named place descriptions,
    # pre/post must be string identifiers
    places: { a: p0, b: p1 }

same for transitions

    # a transition description is an object with
    # pre and post attributes, either an array of strings
    transition = { pre: ['a'], post: ['a'] }

    # or integers, depending on type of the 'places' attr
    transition = { pre: [1], post: [2] }

    # list of unamed transition descriptions
    transitions: [ transition ]

    # dictionary of named transitions
    transitions: { t: transition }

There is a canonical form though, which is dictionaries all the
way baby.

So the description structure of a petri net is

```
Petrinet = {
    places: {
        id: { place }
    }
    transitions: {
        id: { transition
            pre: {
                id: { arc }
            }
            post: {
                id: { arc }
            }
        }
    }
}
```

#### Short note on javascript

It sucks. So does coffee script. Ok, fine. This shit is workable.
But come one, for this stuff you want typeclasses & monoids and fun.
Look at that `.isNumber` and `.isArray` code.

#### Specifying a marking or multiset.

You give a dictionary from places to an array of tokens in that place.

    m = {A: [{},{}], B: [{}]}

These should be integers, if the collection of places is an array.

    m = {1: [{},{}], 2: [{}]}

If all you care about are empty tokens, you might as well just give a number

    m = {A: 2, B: 1}
    m = {1: 2, 2: 1}

You can even mix this, but try no to do that, it's weird.

    # TODO this might lead to bugs at the moment
    m = {A: 2, B: [{}]}

##### Functions on multisets

We define *>*, *-* and *+*, `gt`, `subtract` and `add` for

    class MultiSet
        constructor: (@M) ->
            # w00t

A helper function to give the multiplicity of an entry in our multiset.

        _multiplicity: (key) ->
            elt = @M[key]

            # the array size is the nr of tokens
            if (_.isArray elt)
                _.size elt

            # nr of tokens is given directly or key is missing
            elt

This multiset is bigger then the other if all of that other multisets'
keys are in our set, and our multiplicity is `>=` theirs. In code,

        gte: (other) ->
            (_ other.M .keys)
                .map (i) ->
                    a = this._multiplicity i)
                    b = (other._multiplicty i)
                    (not a and not b) or (a >= b)
                .all

Some shit to deal with polymorphic entries (lists or numbers).

        _add: (key, elts) ->

            A = @M[key]
            B = elts

            listA = _.isArray A
            numA = _.isNumber A
            listB = _.isArray B
            numB = _.isNumber B

            if (listA and listB)
                A.concat B

            if (numA and numB)
                A + B

            # list [{}, ..., {}] of size n
            toList = (n) -> _(n).range().map(-> {})

            if (listA and numB)
                A.concat(toList numB)

            if (numA and listB)
                (toList numA).concat B

Now adding is simple.

        add: (other) ->
            mm = _.map other.M, (val, key) ->
                this._add(key, val)

            new MultiSet (_.extend (_.clone @M) mm)

Although this is inefficient.

### Describing a whole net

Lets create a simple net `()-->[]-->()`. Every ALLCAPS key is
an identifier you can freely choose.

    P = {
        places: {A:{}, B:{}},
        transitions: {
            T: {
                pre: {A:{}},
                post: {B:{}}
            }
        },
        initial: {
            START:{
                # start with two tokens in 'A'
                A: [{},{}]
            }
        },
        terminal: {
            END: {
                # end once they are both in 'B'
                B: [{},{}]
            }
        }
    };

Lets first write a little helper functions to consistently pick an from our collections. If the collection contains only one object,
it is always the default. Otherwise an object is picked using
function argument `key`.

    pick = (collection, key) ->
        if (_ collection .size == 1)
            (_ collection .values) .first
        else
            collection[key] or throw new Error 'invalid key'

Lodash nicely lets us abstract arrays and dictionaries here and
handle both.

## Process

Since we are going to create some functions working on this
structure, we are going to wrap it.

    class Process
        constructor: ( @P ) ->
            # yep

### Creating an initial marking

The frozen state of an instance of a process is called *marking*.
Markings are just multisets over the places, represented to you as
a dictionary of arrays containing tokens.

```
exampleMarking = {
    A: [{}, {}, {}]
    B: [{}]
}
```

Now lets add functionality to create a fresh marking for our process using one of the specified initial markings.

        initialMarking: (key, token_data) ->

We first pick the right initial marking.

            initial = pick @P.initial, key

We should now

            # TODO token data should be mixed in as follows
            # each key in init
            # if key in token_data, check [] lenths
            # if match, clone that and add as key,
            # if don't match, fail (invalid initial marking)

But instead we just clone the picked `initial`.

            # create new
            return (_ initial) .clone

### The "Firing Relation".

So what is this relation? It is a mathematical gadget to precisly
describe using logic when a transition can fire and what it means
for the state of a process.

More precisly, it is a ternary relation between markings before firing a transition, the transition, and the markings after firing a transition.

Whole mouthful, so lets introduce the notation
*m_0 --> t --> m_1* for this (suggesting "*m_1* is the result of firing *t* on *m_0*").

So those three are related once

```
    m0 -- t --> m1   <=>  m0 > t.pre  /\  m1 = m0 - t.pre + t.post
```
Now this only makes sense once we define `gt`, `subtract` and `add` for markings and `pre`/`post`.

Alright, so lets first create our initial marking.

    p = new Process P
    m0 = p.initialMarking 'START' # key doesn't matter, for clarity


Great, let's write a function to compute the next state after firing
a transition.

    Process.prototype.transitionMarking = (marking, transition) ->
        marking

# The Statebox RESTful Protocol

Now it's time for the real fun.

    app.get '/posts/:postId.json', (request, postId) ->
        Q.fcall ->
            [1,2,3,postId]
        .then (s) ->
            _(s)
            .map( (x) -> x + x )
            .value()
        .then (s) ->
            JSON.stringify s
            # _.map(s, (x) -> x + x)
        # .then (s) ->
        #     s && s.toString || 404


Promises coffee style.

Now lets start the server

    mach.serve app, 3000
