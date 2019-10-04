Harmonia: JBoss SET Continous Integration Job Scripts
====

This project holds the script used to build the EAP testsuite inside a Jenkins job. Those jobs
generally runs several testsuite in parallel (on different JVM) and thus requires some extra work to
set up a proper Docker environnement for it to run.

The script are designed to be pretty generic and used as a base for *any* job. However, if needed,
job specific items can be stored in different branch than master.


Note:
[Harmonia](https://en.wikipedia.org/wiki/Harmonia_(mythology)) is one of the infant of Zeus - which is the named of the
Ansible configuration in charge of Thunder.

Development
----

To run testsuite execute:

```bats -t tests/```

