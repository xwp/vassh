The big pain of doing `vagrant ssh` is that it doesn’t drop you into the corresponding working directory in the Vagrant guest’s synced_folder, so you have to `cd` to the dir and then run `wp`. So `vassh` will make sure you start out in the corresponding directory. So if you’re in your WordPress project on your host machine, all you need to do is:

```sh
$ vassh wp core update
```

There’s also a wrapper called `vasshin` which will shell you into Vagrant at the current directory, with a prompt for entering commands. This gets you colors and interactive tty. You can also pass commands as arguments to `vasshin` to have them executed right away in the colorized tty (with some additional Vagrant .bash_login echoes and SSH connection close):

```sh
$ vasshin wp post list # nice table!
```