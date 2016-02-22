# RabbitMQ/OMF Presentation - Second

## RabbitMQ
`basic.consume`, `exchange.declare`, `queue.declare`,  `basic.publish`, etc
all use the RPC method, which simply calls *send* on the socket. As the socket is *non-blocking* if send cannot be done this call will fail. 

Additionally, a timeout is used in `amqp_try_send`/`amqp_try_read` to `poll` in case not all bytes can be sent/read. The timeout used if the connections *heartbeat* value.

The `simple_rpc` method after sending a method using `amqp_send_method` calls `wait_frame_inner` to get a response from the server to find out if the method worked (and get any necessary reply parameters e.g. queue name when server should set it).

`consume_message` indirectly uses `select` or `poll`, before `recv`, with a user provided timeout if any, i.e. the call can be made effectively non-blocking.

JS experiment: hello world was printed even though server was killed. so i guess the implementation is fully asynchronous and error is being ignored due to not passing a callback to handle it.

# OMF
notes wip

# RabbitMQ Presentation - First

AMQP: standard for message passing
- dev started by JPMorgan
- meant to replace proprietary system
- enable systems from different orgs to communicate through a common interface
- programmatic

Consumers are agnostic to producsers and vice-versa

Protocol itself allows for provisioning of entities

Messages: label + payload
- label has attributes
- attributes potentially contain headers, which are broker specific
-  The communication is fire-and-forget and one-directional.

RabbitMQ is a message broker that enables fast and reliable message passing facilitating of decoupled applications in a distributed fashion.

- Built on Erlang *“Build massively scalable soft real-time systems”*
- Low latency
- Fault Tolerant
- Reliable
- Enables dev of decoupled and distributed apps

 Not only can
using transactions drop your message throughput by a factor of 2–10x, but they also
make your producer app synchronous

 decoupling problem. How do you take a time-intensive
task and move it out of the app that triggers it (thereby freeing that app to service
other requests) =>  decoupling the request from
the action.
