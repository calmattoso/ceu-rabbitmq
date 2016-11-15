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
# Work Queues

## Introduction

> #### Prerequisites
> This tutorial assumes RabbitMQ is [installed](https://www.rabbitmq.com/download.html) and running on localhost on standard port (5672). In case you use a different host, port or credentials, connections settings would require adjusting.

![Work queues diagram](https://www.rabbitmq.com/img/tutorials/python-two.png)

In the [first tutorial](../hello_world/) we wrote programs to send and receive messages from a named queue. In this one we'll create a _Work Queue_ (aka: _Task Queues_) that will be used to distribute time-consuming tasks among multiple workers.

The main idea behind Work Queues (aka: Task Queues) is to avoid doing a resource-intensive task immediately and having to wait for it to complete. Instead we schedule the task to be done later. We encapsulate a task as a message and send it to a queue. A worker process running in the background will pop the tasks and eventually execute the job. When you run many workers the tasks will be shared between them.

This concept is especially useful in web applications where it's impossible to handle a complex task during a short HTTP request window.

## Preparation

In the previous part of this tutorial we sent a message containing
"Hello World!". Now we'll be sending strings that stand for complex
tasks. We don't have a real-world task, like images to be resized or
pdf files to be rendered, so let's fake it by just pretending we're
busy - by using the `await` statement. We'll take a number and sleep
for that many seconds; so if we get 3, we'll sleep for 3s.

We will slightly modify the _send.ceu_ code from our previous example,
to randomly generate messages that carry such number. This
program will schedule tasks to our work queue, so let's name it
`new_task.ceu`:

```c
[[ math.randomseed(os.time()) ]];
var        int  task_id = [[ math.random(10) ]];
vector[50] byte task_msg = [] .. "";
_sprintf((&&task_msg[0] as _char&&), "%d", task_id);

RMQ_Publish(channel, amq_default, PublishContext("task_queue", (&&task_msg[0] as _char&&),_,_,default_props));

_printf("Posted a new task: %s\n", (&&task_msg[0] as _char&&));
```

Our old _receive.ceu_ script also remains the same, we just rename it to `worker.ceu`. As we're using the `Handler` module paradigm in Céu, that's where we'll make changes. In order to observe the delay in message processing we'll output a "Processing done..." message after awaiting for as many seconds as specified by the message.

```c

```

Note that our fake task simulates execution time.

Run them as in tutorial one:

```bash
$ make example SAMPLE=work_queues TARGET=worker
$ make example SAMPLE=work_queues TARGET=new_task
```

Round-robin dispatching
-----------------------

One of the advantages of using a Task Queue is the ability to easily
parallelise work. If we are building up a backlog of work, we can just
add more workers and that way, scale easily.

First, let's try to run two `worker.ceu` scripts at the same time. They
will both get messages from the queue, but how exactly? Let's see.

You need three consoles open. Two will run the `worker.ceu`
script. These consoles will be our two consumers - C1 and C2.

```bash
shell1$ make example SAMPLE=work_queues TARGET=worker
...
Consuming messages from queue `task_queue`...
```

```bash
shell2$ make example SAMPLE=work_queues TARGET=worker
...
Consuming messages from queue `task_queue`...
```

In the third one we'll publish new tasks. Once you've started
the consumers you can publish a few messages:

```bash
shell3$ make example SAMPLE=work_queues TARGET=new_task
Posted a new task: 6
shell3$ make example SAMPLE=work_queues TARGET=new_task
Posted a new task: 11
shell3$ make example SAMPLE=work_queues TARGET=new_task
Posted a new task: 9
shell3$ make example SAMPLE=work_queues TARGET=new_task
Posted a new task: 6
shell3$ make example SAMPLE=work_queues TARGET=new_task
Posted a new task: 2
```

Let's see a sample of what can be delivered to our workers. As the messages are generated randomly, you'll likely observe different results. The number at the beginning of each line is an identifier that allows matching the start and end of a message processing task.

```bash
shell1$ make example SAMPLE=work_queues TARGET=worker
[1] Processing message for 6 seconds.
[2] Processing message for 9 seconds.
[1] Processed message for 6 seconds!
[2] Processed message for 9 seconds!
[3] Processing message for 2 seconds.
[3] Processed message for 2 seconds!
```

```bash
shell2$ make example SAMPLE=work_queues TARGET=worker
[1] Processing message for 11 seconds.
[1] Processed message for 11 seconds!
[2] Processing message for 6 seconds.
[2] Processed message for 6 seconds!
```

By default, RabbitMQ will send each message to the next consumer,
in sequence. On average every consumer will get the same number of
messages. This way of distributing messages is called round-robin. Try
this out with three or more workers.


Message acknowledgment
----------------------

Doing a task can take a few seconds. You may wonder what happens if
one of the consumers starts a long task and dies with it only partly done.
With our current code, once RabbitMQ delivers a message to the customer it
immediately removes it from memory. In this case, if you kill a worker
we will lose the message it was just processing. We'll also lose all
the messages that were dispatched to this particular worker but were not
yet handled.

But we don't want to lose any tasks. If a worker dies, we'd like the
task to be delivered to another worker.

In order to make sure a message is never lost, RabbitMQ supports
message _acknowledgments_. An ack(nowledgement) is sent back from the
consumer to tell RabbitMQ that a particular message has been received,
processed and that RabbitMQ is free to delete it.

If a consumer dies (its channel is closed, connection is closed, or
TCP connection is lost) without sending an ack, RabbitMQ will
understand that a message wasn't processed fully and will re-queue it.
If there are other consumers online at the same time, it will then quickly redeliver it
to another consumer. That way you can be sure that no message is lost,
even if the workers occasionally die.

There aren't any message timeouts; RabbitMQ will redeliver the message when
the consumer dies. It's fine even if processing a message takes a very, very
long time.

Message acknowledgments are turned off by default.
It's time to turn them on using the `no_ack` field on the `SubscribeContext` and send a proper acknowledgment from the worker, once we're done with a task. We set the `no_ack` to `false` below in order to require message acknowledgments.

```c
RMQ_Subscribe(channel, queue, SubscribeContext(_,false,_,_), 10, qsub_ok);
```

Note that a great advantage of the `ceu-rabbitmq` library is that it [automatically handles message acknowledgment](../channel.ceu#L40-L47). This is done if `no_ack` was set to `true` for the subscription through which we received the message and happens after the `Handler` instance successfully terminates.

Using this code we can be sure that even if you kill a worker using
CTRL+C while it was processing a message, nothing will be lost. Soon
after the worker dies all unacknowledged messages will be redelivered.

> #### Forgotten acknowledgment
>
> It's a common mistake to miss the `ack`. It's an easy error,
> but the consequences are serious. Messages will be redelivered
> when your client quits (which may look like random redelivery), but
> RabbitMQ will eat more and more memory as it won't be able to release
> any unacked messages.
>
> In order to debug this kind of mistake you can use `rabbitmqctl`
> to print the `messages_unacknowledged` field:
>
>```bash
> $ sudo rabbitmqctl list_queues name messages_ready messages_unacknowledged
> Listing queues ...
> hello    0       0
> ...done.
>```

Message durability
------------------

We have learned how to make sure that even if the consumer dies, the
task isn't lost. But our tasks will still be lost if RabbitMQ server stops.

When RabbitMQ quits or crashes it will forget the queues and messages
unless you tell it not to. Two things are required to make sure that
messages aren't lost: we need to mark both the queue and messages as
durable.

First, we need to make sure that RabbitMQ will never lose our
queue. In order to do so, we need to declare it as _durable_, by
setting the second argument of `QueueContext` to true.

```c
RMQ_Queue(channel, QueueContext("hello",_,true,_,_,_amqp_empty_table), queue, q_ok);
```

Although this command is correct by itself, it won't work in our present
setup. That's because we've already defined a queue called `hello`
which is not durable. RabbitMQ doesn't allow you to redefine an existing queue
with different parameters and will return an error to any program
that tries to do that. But there is a quick workaround - let's declare
a queue with different name, for example `task_queue`:

```c
RMQ_Queue(channel, QueueContext("task_queue",_,true,_,_,_amqp_empty_table), queue, q_ok);
```

At this point we're sure that the `task_queue` queue won't be lost
even if RabbitMQ restarts. Now we need to mark our messages as persistent
- by using the `persistent` delivery mode option when publishing a message.
Note that the `default_props` object provided by the `publish.ceu` module
already has this done for you. Below we show how to do it:

```
var _amqp_basic_properties_t default_props = _;
//...
default_props.delivery_mode = 2; // persistent mode
```

For now, you must refer to [`rabbitmq-c` documentation](https://github.com/alanxz/rabbitmq-c/blob/b1acb373661a9a799428b50fa402be231013e374/librabbitmq/amqp_framing.h#L711-L743) in order to learn how to configure this object.

> #### Note on message persistence
>
> Marking messages as persistent doesn't fully guarantee that a message
> won't be lost. Although it tells RabbitMQ to save the message to disk,
> there is still a short time window when RabbitMQ has accepted a message and
> hasn't saved it yet. Also, RabbitMQ doesn't do `fsync(2)` for every
> message -- it may be just saved to cache and not really written to the
> disk. The persistence guarantees aren't strong, but it's more than enough
> for our simple task queue. If you need a stronger guarantee then you can use
> [publisher confirms](https://www.rabbitmq.com/confirms.html).


Fair dispatch
----------------

You might have noticed that the dispatching still doesn't work exactly
as we want. For example in a situation with two workers, when all
odd messages are heavy and even messages are light, one worker will be
constantly busy and the other one will do hardly any work. Well,
RabbitMQ doesn't know anything about that and will still dispatch
messages evenly.

This happens because RabbitMQ just dispatches a message when the message
enters the queue. It doesn't look at the number of unacknowledged
messages for a consumer. It just blindly dispatches every n-th message
to the n-th consumer.

![Fair dispatch diagram](https://www.rabbitmq.com/img/tutorials/prefetch-count.png)

In order to defeat that we can use the `prefetch` method with the
value of `1`. This tells RabbitMQ not to give more than
one message to a worker at a time. Or, in other words, don't dispatch
a new message to a worker until it has processed and acknowledged the
previous one. Instead, it will dispatch it to the next worker that is not still busy.

```c
// Set prefetch to 1 message
event& void qos_ok;
RMQ_Qos(channel, QosContext(1,_), qos_ok);
```

> #### Note about queue size
>
> If all the workers are busy, your queue can fill up. You will want to keep an
> eye on that, and maybe add more workers, or have some other strategy.

Putting it all together
-----------------------

Final code of our `new_task.ceu` class:
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

// Generate task msg
[[ math.randomseed(os.time()) ]];
var        int  task_id = [[ math.random(15) ]];
vector[50] byte task_msg = [] .. "";
_sprintf((&&task_msg[0] as _char&&), "%d", task_id);

RMQ_Publish(channel, amq_default, PublishContext("task_queue", (&&task_msg[0] as _char&&),_,_,default_props));

_printf("Posted a new task: %s\n", (&&task_msg[0] as _char&&));

escape 0;

```
[(new_task.ceu source)](new_task.ceu)

And our `worker.ceu`:
```c
#include <c.ceu>
#include <uv/uv.ceu>

#include <connection.ceu>
#include "handler.ceu"
#include <channel.ceu>
#include <queue.ceu>
#include <q_subscribe.ceu>
#include <qos.ceu>

var& Connection conn;
event& void conn_ok;
RMQ_Connection(_, conn, conn_ok);

var& Channel channel;
event& void ch_ok;
RMQ_Channel(conn, channel, ch_ok);

var& Queue queue;
event& void q_ok;
RMQ_Queue(channel, QueueContext("task_queue",_,true,_,_,_amqp_empty_table), queue, q_ok);

// Set ack to true...
event& void qsub_ok;
RMQ_Subscribe(channel, queue, SubscribeContext(_,false,_,_), 10, qsub_ok);

// Set prefetch to 1 message
event& void qos_ok;
RMQ_Qos(channel, QosContext(1,_), qos_ok);

// Setup is done, so activate consumption
RMQ_Consume(channel, default_handlers);

_printf("Consuming messages from queue `task_queue`...\n\n");

await FOREVER;
```
[(worker.ceu source)](worker.ceu)

Finally, the handler:
```c
#ifndef _HANDLER_CEU
#define _HANDLER_CEU

#include <c.ceu>
#include <uv/uv.ceu>
#include <amqp_base.ceu>
#include <envelope.ceu>

native/pre do
    int get_int(char* msg) {
        int ret;
        sscanf(msg, " %d", &ret);
        return ret;
    }
end

native/nohold
    _get_int,
;

code/await Handler (var Envelope env) -> void do
    var _plain_string msg = _stringify_bytes(env.contents.message.body);
    var int proc_time = _get_int(msg);
    _free(msg);

    _printf("[%lu] Processing message for %d seconds.\n", env.contents.delivery_tag, proc_time);
    await (proc_time)s;
    _printf("[%lu] Processed message for %d seconds!\n", env.contents.delivery_tag, proc_time);
end

#endif
```
[(handler.ceu source)](handler.ceu)

Using message acknowledgments and `prefetch` you can set up a
work queue. The durability options let the tasks survive even if
RabbitMQ is restarted.

Now we can move on to [tutorial 3](../pubsub) and learn how
to deliver the same message to many consumers.
