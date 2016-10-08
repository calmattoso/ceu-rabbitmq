CEU_DIR    = $(error set absolute path to "<ceu>" repository)
CEU_UV_DIR = $(error set absolute path to "<ceu-uv>" repository)

all:

connection:
	ceu --pre --pre-args="-I$(CEU_DIR)/include -I$(CEU_UV_DIR)/include" \
	          --pre-input=src/connection.ceu                            \
	    --ceu                                                           \
	    --env --env-types=$(CEU_DIR)/env/types.h                        \
	          --env-threads=$(CEU_UV_DIR)/env/threads.h                 \
	          --env-main=$(CEU_DIR)/env/main.c                          \
	    --cc --cc-args="-Isrc/ -lrabbitmq -llua5.3 -lpthread -luv"      \
	         --cc-output=connection
	./connection

.PHONY: all connection
