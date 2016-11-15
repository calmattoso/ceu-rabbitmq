<!--
Copyright (c) 2007-2016 Pivotal Software, Inc.

All rights reserved. This program and the accompanying materials
are made available under the terms of the under the Apache License, 
Version 2.0 (the "License”); you may not use this file except in compliance 
with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->
# RabbitMQ tutorial - "Hello World!"

## Introduction

> #### Prerequisites
> This tutorial assumes RabbitMQ is [installed](https://www.rabbitmq.com/download.html) and running on localhost on standard port (5672). In case you use a different host, port or credentials, connections settings would require adjusting.

RabbitMQ is a message broker. The principal idea is pretty simple: it accepts and forwards messages. You can think about it as a post office: when you send mail to the post box you're pretty sure that Mr. Postman will eventually deliver the mail to your recipient. Using this metaphor RabbitMQ is a post box, a post office and a postman.

The major difference between RabbitMQ and the post office is the fact that it doesn't deal with paper, instead it accepts, stores and forwards binary blobs of data ‒ _messages_.

RabbitMQ, and messaging in general, uses some jargon.

- _Producing_ means nothing more than sending. A program that sends messages is a _producer_. We'll draw it like that, with "P":

![Producer](https://www.rabbitmq.com/img/tutorials/producer.png)

- A _queue_ is the name for a mailbox. It lives inside RabbitMQ. Although messages flow through RabbitMQ and your applications, they can be stored only inside a _queue_. A _queue_ is not bound by any limits, it can store as many messages as you like ‒ it's essentially an infinite buffer. Many _producers_ can send messages that go to one _queue_, many _consumers_ can try to receive data from one _queue_. A _queue_ will be drawn as like that, with its name above it:
> Note: Producers actually publish messages to _exchanges_, which in turn publish them to queues.

![Queue](https://www.rabbitmq.com/img/tutorials/queue.png)

- _Consuming_ has a similar meaning to receiving. A consumer is a program that mostly waits to receive messages. On our drawings it's shown with "C":

![Consumer](https://www.rabbitmq.com/img/tutorials/consumer.png)

Note that the producer, consumer, and broker do not have to reside on the same machine; indeed in most applications they don't.

## "Hello World"
### (using the Céu RabbitMQ Client)

In this part of the tutorial we'll write two small programs in Céu; a producer that sends a single message, and a consumer that receives messages and prints them out.  We'll gloss over some of the detail in the [ceu-rabbitmq](https://github.com/calmattoso/ceu-rabbitmq/) API, concentrating on this very simple thing just to get started. It's a "Hello World" of messaging.

In the diagram below, "P" is our producer and "C" is our consumer. The box in the middle is a queue - a message buffer that RabbitMQ keeps on behalf of the consumer.

<div class="diagram">
  <img src="https://www.rabbitmq.com/img/tutorials/python-one.png" alt="(P) -> [|||] -> (C)" height="60" />
</div>

> #### The `ceu-rabbitmq` client library
> RabbitMQ speaks multiple protocols. This tutorial uses AMQP 0-9-1, which is an open,
> general-purpose protocol for messaging. There are a number of clients
> for RabbitMQ in [many different
> languages](http://rabbitmq.com/devtools.html). We'll
> use the [ceu-rabbitmq](https://github.com/calmattoso/ceu-rabbitmq/), the most popular Céu client, in this tutorial.
>
> First, install `ceu-rabbitmq` by cloning the [GitHub repository](https://github.com/calmattoso/ceu-rabbitmq/) and following the
> instructions to set everything up. 
>
>```bash
>$ git clone https://github.com/calmattoso/ceu-rabbitmq.git
>```

Now we have `ceu-rabbitmq` installed, we can write some code.

### Sending

<div class="diagram">
  <img src="https://www.rabbitmq.com/img/tutorials/sending.png" alt="(P) -> [|||]" height="100" />
</div>

We'll call our message sender `send.ceu` and our message receiver `receive.ceu`.  The sender will connect to RabbitMQ, send a single message, then exit.

In [`send.ceu`](https://github.com/calmattoso/ceu-rabbitmq/blob/master/src/hello_world/send.ceu), we need to require the necessary Céu modules:

```c
#include <c.ceu>
#include <uv/uv.ceu>
```
> Note: We're using the [ceu-libuv](https://github.com/fsantanna/ceu-libuv) environment for all tutorials.

Now include the modules we'll be using from the library:
```c
#include <connection.ceu>
#include <channel.ceu>
#include <publish.ceu>
```

Then connect to RabbitMQ server
```c
var& Connection conn;
event& void conn_ok;
RMQ_Connection(_, conn, conn_ok);
```

The connection abstracts the socket connection, and takes care of protocol version negotiation and authentication and so on for us. Additionally, we're using the `RMQ_Connection` macro, which takes care of both spawning the code block that starts the connection and of waiting for `conn_ok` to be triggered. Note that here we connect to a broker on the local machine with all default settings.

> Note: You can always use the underlying API call instead of the published macros. But macros make the code simpler by abstracting work you'd have to do regardless. 

If we wanted to connect to a broker on a different machine we'd simply specify its name or IP address by setting the `hostname` field of the `ConnectionContext` object taken by the macro:

```c
RMQ_Connection(ConnectionContext("rabbit.local",_,_,_,_,_,_,_), conn, conn_ok);
```

Next we create a channel, an entity that a lot of API calls depend on:

```c
var& Channel channel;
event& void ch_ok;
RMQ_Channel(conn, channel, ch_ok);
```

To send, we must publish the message to some exchange. For simplicity, we're just using the default exchange:

```c
RMQ_Publish(channel, amq_default, PublishContext("hello", "Hello from Ceu!",_,_,default_props));
```

Observe that we use a variable called `amq_default`, which references the default exchange. In most libraries the exchange is referenced by it's name only, which for the default is "" (yes, the empty string!) Instead of having the user rely on strings, we provide pre-defined instances of the `Exchange` data object for each of the default exchanges (i.e. '', 'amq.direct', 'amq.topic', 'amq.headers', 'amq.fanout'.)

Also pay attention to the _routing key_: `hello`. As we're using the default exchange, messages sent to it with such key will go to queues whose name is `hello`. This is because all queues are automatically bound to the default exchange with a _binding key_ equal to their names.

Finally, all entities that were used will be cleaned up, if applicable, by order of declaration, from latest to earliest. In this case, that means the connection will be closed automatically. Therefore, you don't have to worry about cleaning up the environment! The library takes care of that for you. :)

> Use this to your advantage! As events come in just take out of scope the relevant entities 
> and clean-up will be automatically done.

Here's the whole [send.ceu](https://github.com/calmattoso/ceu-rabbitmq/blob/master/src/hello_world/send.ceu) script:
```c
#include <c.ceu>
#include <uv/uv.ceu>

#include <connection.ceu>
#include <channel.ceu>
#include <publish.ceu>

var& Connection conn;
event& void conn_ok;
RMQ_Connection(_, conn, conn_ok);

var& Channel channel;
event& void ch_ok;
RMQ_Channel(conn, channel, ch_ok);

RMQ_Publish(channel, amq_default, PublishContext("hello", "Hello from Ceu!",_,_,default_props));
_printf("Published a message...\n");

escape 0;
```

> #### Sending doesn't work!
>
> If this is your first time using RabbitMQ and you don't see the "Sent"
> message then you may be left scratching your head wondering what could
> be wrong. Maybe the broker was started without enough free disk space
> (by default it needs at least 1Gb free) and is therefore refusing to
> accept messages. Check the broker logfile to confirm and reduce the
> limit if necessary. The <a
> href="http://www.rabbitmq.com/configure.html#config-items">configuration
> file documentation</a> will show you how to set <code>disk_free_limit</code>.


### Receiving

That's it for our sender.  Our receiver is pushed messages from
RabbitMQ, so unlike the sender which publishes a single message, we'll
keep it running to listen for messages and print them out.

<div class="diagram">
  <img src="https://www.rabbitmq.com/img/tutorials/receiving.png" alt="[|||] -> (C)" height="100" />
</div>

The code (in [`receive.ceu`](https://github.com/calmattoso/ceu-rabbitmq/blob/master/src/hello_world/receive.ceu)) has similar includes as `send`:

```c
#include <c.ceu>
#include <uv/uv.ceu>

#include "handler.ceu"
#include <connection.ceu>
#include <channel.ceu>
#include <queue.ceu>
#include <q_subscribe.ceu>
```

We're also including two new modules: `queue` and `q_subscribe`. The first lets us declare queues, and the second is used to subscribe to queues. We'll talk about the `handler.ceu` later.

> Note: __Always__ include `handler.ceu` before `channel.ceu`.

Setting up is the same as the sender; we open a connection and a channel. Then we declare the queue from which we're going to consume. Note that the name of this queue matches up with the routing key with which `send` publishes.

```c
var& Connection conn;
event& void conn_ok;
RMQ_Connection(_, conn, conn_ok);

var& Channel channel;
event& void ch_ok;
RMQ_Channel(conn, channel, ch_ok);

var& Queue queue;
event& void q_ok;
RMQ_Queue(channel, QueueContext("hello",_,_,_,_,_amqp_empty_table), queue, q_ok);
```

We're about to tell the server to deliver us the messages from the queue. Since it will push us messages asynchronously, we must have some way to deal with incoming messages. That's where the `handler.ceu` comes in. This is a user provided module that must handle __all__ received messages. But, you might ask, how would you know which queue a message came from and what to do with it? In other languages you usually specify a callback for each queue to which you subscribe. In `ceu-rabbitmq`, the message by having an `htag` field, shorthand for _handler tag_. This value is derived from the queue where the message originates, and is specified by the user when subscribing to a queue. That way, all messages coming from such queue will have the same `htag`. In the handler, all you have to do is check the `htag` and spawn the actual concrete handler.

For this tutorial the handler doesn't care about the `htag`, it just prints out the contents of the messages: 
```c
code/await Handler (var Envelope env) -> void do
    _printf("#==============================================================================#\n");
    _printf("\tHOLA! Received message for handler with tag `%d`.\n", env.handler_tag);
    _printf("\tMsg: %s\n", _stringify_bytes(env.contents.message.body));
    _printf("#==============================================================================#\n\n");
end
```
[Here's the whole handler.ceu script](https://github.com/calmattoso/ceu-rabbitmq/blob/master/src/hello_world/handler.ceu).

Below, see how to subscribe to the queue. Note the argument of value 10, that's the `htag` value for this subscription!
```c
event& void qsub_ok;
RMQ_Subscribe(channel, queue, _, 10, qsub_ok);
```

Finally, we must set the channel to be in consume mode:
```c
RMQ_Consume(channel, default_handlers);
_printf("Consuming messages from default exchange with key `hello`...\n\n");
await FOREVER;
```

Some additional technical details. `default_handlers` is a default pool provided by the library in which handlers are instantiated. Moreover, where do messages come from? When calling `RMQ_Consume` an infinite `loop` is started, and it simply consumes new messages and dispatches them to an intance of the user provided `Handler`. As we don't want our application to finish running immediately, we await forever.

Here's the whole [receive.ceu](https://github.com/calmattoso/ceu-rabbitmq/blob/master/src/hello_world/receive.ceu) script:
```c
#include <c.ceu>
#include <uv/uv.ceu>

#include <connection.ceu>
#include "handler.ceu"
#include <channel.ceu>
#include <queue.ceu>
#include <q_subscribe.ceu>

var& Connection conn;
event& void conn_ok;
RMQ_Connection(_, conn, conn_ok);

var& Channel channel;
event& void ch_ok;
RMQ_Channel(conn, channel, ch_ok);

var& Queue queue;
event& void q_ok;
RMQ_Queue(channel, QueueContext("hello",_,_,_,_,_amqp_empty_table), queue, q_ok);

event& void qsub_ok;
RMQ_Subscribe(channel, queue, _, 10, qsub_ok);

// Setup is done, so activate consumption
RMQ_Consume(channel, default_handlers);

_printf("Consuming messages from default exchange with key `hello`...\n\n");

await FOREVER;
```

### Putting it all together

Now we can run both scripts. In a terminal, from the top level directory of ceu-rabbitmq, run:
```bash
$ make example SAMPLE=hello_world TARGET=receive
```

Then, run the sender:
```bash
$ make example SAMPLE=hello_world TARGET=send
```

The receiver will print the message it gets from the sender via RabbitMQ. The receiver will keep running, waiting for messages (Use Ctrl-C to stop it), so try running the sender from another terminal.

If you want to check on the queue, try using `rabbitmqctl list_queues`.

Hello World!

Time to move on to [part 2](../work_queues/) and build a simple _work queue_.
