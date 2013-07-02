# lita-totems

A Lita handler for managing shared engineering resources.

## Usage

Totems is a system of waiting lists that allow engineers to be given control of a shared resource, such as a demo environment, in first-in-first-out order. The user at the front of the queue is said to hold the "totem" for that queue, and hence, each queue is given a named totem.

### Creating and destroying totems

To create or destroy a totem and its queue, a user must be in the `:totem_admins` authorization group. They can then message the bot these commands:

```
totems create my_totem
totems destroy my_totem
```

### Queueing

Once a totem is created, users can add themselves to the queue for it:

```
totems add my_totem
```

If no other users are in the queue, they will gain possession of the totem until they yield it. If there are other users in the queue, the bot will send them a private message letting them know when the reach the front of the queue and gain possession of the totem.

### Listing

To see the queue for all the totems, message the bot:

```
totems
```

If you only care about one particular totem, pass its name:

```
totems my_totem
```

### Yielding

When you have control of a totem and you're finished with it, you should yield it. This gives control of the totem to the next user in the queue.

```
totems yield my_totem
```

### Kicking

On some occasions, the user with control of a totem may forget to yield and then become unavailable. Kicking someone forcefully removes them from the queue. To kick the person at the front of the queue:

```
totems kick my_totem
```

If you want to kick a specific person in the queue (they need not be at the front):

```
totems kick my_totem "Joe Shmoe"
```
