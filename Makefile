CEU_DIR     = /home/carlos/ceu#$(error set absolute path to "<ceu>" repository)
CEU_UV_DIR  = /home/carlos/ceu-libuv#$(error set absolute path to "<ceu-uv>" repository)
CEU_RMQ_DIR = /home/carlos/ceu-rabbitmq

CEU_ARGS = --ceu --ceu-features-lua=true                               \
                 --ceu-features-thread=true                            \
                 --ceu-err-unused=pass                                 \
                 --ceu-err-uninitialized=pass                          \
	       --env --env-types=$(CEU_DIR)/env/types.h                    \
	             --env-threads=$(CEU_DIR)/env/threads.h             \
	             --env-main=$(CEU_DIR)/env/main.c                      \
	        --cc --cc-args="-Isrc/ -lrabbitmq -llua5.3 -lpthread -luv" \
	             --cc-output=$(TARGET)

all:

test:
	ceu --pre --pre-args="-I$(CEU_DIR)/include -I$(CEU_UV_DIR)/include -DDEBUG -D$(TARGET)_test" \
	          --pre-input=src/$(TARGET).ceu $(CEU_ARGS)
	    
	./$(TARGET)

example:
	ceu --pre --pre-args="-I$(CEU_DIR)/include -I$(CEU_UV_DIR)/include -I$(CEU_RMQ_DIR)/src -DDEBUG" \
	          --pre-input=src/$(SAMPLE)/$(TARGET).ceu $(CEU_ARGS)
	    
	./$(TARGET)

.PHONY: all connection example
