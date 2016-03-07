# Mini-Tutorial for RabbitMQ & rabbitmq-c
## Install RabbitMQ
Run the following commands:
```bash
sudo apt-get install build-essential libssl-dev
sudo apt-get install rabbitmq-server
```
RabbitMQ should now be installed on your machine. To run it, do:
```bash
sudo rabbitmq-server start
```
*Note: it's possible that after installation the server will already be running, which is fine. Upon trying to start it you'll be notified if this is the case.*

### Test RabbitMQ (with examples in Python)
In order to make sure the serving is working, let's use two basic examples from the official [Python tutorial on RabbitMQ](https://www.rabbitmq.com/tutorials/tutorial-one-python.html
). 

Before, we must install `pip`, a Python package manager, and `pika`, an AMQP library for Python applications:
```bash
sudo apt-get install python-pip
sudo pip install pika
```

Now, run the following commands to download the `receive.py` and `send.py` scripts:
```bash
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/receive.py
wget https://raw.githubusercontent.com/rabbitmq/rabbitmq-tutorials/master/python/send.py
```

Now, start `rabbitmq-server` if you haven't already, and start `receive.py` in it's own tab on the terminal.

Finally, run `send.py`:
```bash
python send.py
```
After doing this, you should see the message *'Hello World!'* show up on the `receive.py` tab. If you wanna change the message sent, modify line 13 in `send.py`.
```bash
 [*] Waiting for messages. To exit press CTRL+C
 [x] Received 'Hello World!'
```

## Install rabbitmq-c
Now, let's install the [C API for AQMP](https://github.com/alanxz/rabbitmq-c). 

First, clone the GitHub repository for `rabbitmq-c`:
```bash
git clone https://github.com/alanxz/rabbitmq-c.git
```
Now, we must build the library. To do so, just run the following commands:
```bash
cd rabbitmq-c
mkdir build && cd build
cmake ..
cmake --build .
```
*Note: if you do not have `libssl` installed, pass the argument -DENABLE_SSL_SUPPORT=OFF to `cmake` above as part of the build process.*

Now, to install the library do:
```bash
cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
cmake --build . --target install
```

If all goes well, examples can be found in `build/examples`.

*Note: More detailed instructions can be found on library's [GitHub repository](https://github.com/alanxz/rabbitmq-c/blob/master/README.md#getting-started).*

### Run the examples
Let's run two simple examples: a publisher and a listener. First, start the listener in its own tab:
```bash
./examples/amqp_listen localhost 5672 amq.direct test
# Usage: amqp_listen <host> <port> <exchange name> <binding key>
```
Here, we're setting the listener to talk to the RabbitMQ server on `localhost` through port `5672`, and consume messages whose `routing key` is `test` from the default direct exchange `amq.direct`. 

Now, we'll send a simple message through `amqp_sendstring.c`:
```bash
./examples/amqp_sendstring localhost 5672 amq.direct test "hello world"
# Usage: amqp_sendstring <host> <port> <exchange name> <binding key> <message body>
```
The first parameters are the same as the ones above. The last one is the body of the message to be sent. 

If all goes well, you should see an output similar to the following:
```bash
Delivery 1, exchange amq.direct routingkey test
Content-type: text/plain
----
00000000: 68 65 6C 6C 6F 20 77 6F : 72 6C 64                 hello world
0000000B:
```

Also try to send a message using `amqp_sendstring` to the Python consumer. In order to do this quickly, just change the `routing key` passed to `amqp_sendstring` above to `hello` and the exchange name to `''` (the default exchange):
```bash
./examples/amqp_sendstring localhost 5672 '' hello "Hello world sent from C!"
```

Setting the `routing key` to `hello` must be done due to no `binding key` having been set in `receive.py`, hence it's set by default to the queue name. Moreover, the default exchange must be used as its the exchange to which the queue is bound to.

You should get the following output:
```bash
 [*] Waiting for messages. To exit press CTRL+C
 [x] Received 'Hello world sent from C!'
```
