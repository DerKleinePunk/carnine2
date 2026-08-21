Ich würde da nun mal den automount von /boot/firmware abdrehen, ebenso das fsck, fsscrub, dpkg-db-backup.
Zudem beim systemd-journald Storage=volatile setzen. Das flush dauert auch etwas.
Es schaut so aus als passiert beim Boot ziemlich viel IO und deine SDcard ist halt langsam. Was bei alten RPis mehr oder weniger normal ist.