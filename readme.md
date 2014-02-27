The big pain of doing `vagrant ssh` is that it doesn’t drop you into the corresponding working directory in the Vagrant guest’s synced_folder, so you have to `cd` to the dir and then run whatever you needed to do (e.g. `wp core update`). This is the problem that `vassh` solves: it will make sure you start out in the corresponding directory. So if you’re in your WordPress project on your host machine, all you need to do is:

```sh
$ vassh wp core update
```

There’s also a wrapper called `vasshin` which will shell you into Vagrant at the current directory, with a prompt for entering commands. This gets you colors and interactive TTY. You can also pass commands as arguments to `vasshin` to have them executed right away in the colorized TTY (with some additional Vagrant `.bash_login` echoes and SSH connection close):

```sh
$ vasshin wp post list # nice table!
```

You can put these files anywhere, as long as you source them via your `.bashrc` or `.bash_profile`.  They aren't read by Vagrant, so they're independent. Example:

```sh
git clone https://github.com/x-team/vassh.git ~/code/vassh
echo "source ~/code/vassh/vassh.sh" >> ~/.bash_profile
source ~/.bash_profile
```

Installation is also now possible via Homebrew ([props @kanedo](https://github.com/x-team/vassh/issues/9)):

```sh
brew update && brew install vassh
```
