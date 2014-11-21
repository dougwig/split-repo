..
 This work is licensed under a Creative Commons Attribution 3.0 Unported
 License.

 http://creativecommons.org/licenses/by/3.0/legalcode

========================================
Proposal for Neutron Services repo split
========================================

Include the URL of your launchpad blueprint:

https://blueprints.launchpad.net/neutron/+spec/services-split

This spec outlines the technical changes required for the repo split.  It is
dependent upon the project split spec:

TBD

The following intro is shamelessly stolen from an email thread started by Mark McClain:

Over the last several months, the members of the Networking Program have been
discussing ways to improve the management of our program.  When the Quantum
project was initially launched, we envisioned a combined service that included
all things network related.  This vision served us well in the early days as
the team mostly focused on building out layers 2 and 3; however, we’ve run into
growth challenges as the project started building out layers 4 through 7.
Initially, we thought that development would float across all layers of the
networking stack, but the reality is that the development concentrates around
either layer 2 and 3 or layers 4 through 7.  In the last few cycles, we’ve also 
discovered that these concentrations have different velocities and a single
core team forces one to match the other to the detriment of the one forced to
slow down.

Going forward we want to divide the Neutron repository into two separate
repositories lead by a common Networking PTL.  The current mission of the
program will remain unchanged.


Problem Description
===================

This proposal deals with the technical aspects of splitting the neutron repo
into two repos, one for basic L2/L3 plumbing, one for advanced services.  The repos will be referred to as "neutron" and "services" within this spec, until
a project name for the "services" repo is selected.

* Currently the neutron code is in a single repo, with a single set of cores.

* After the split, we want all "services" code and db models will be in a new
  services repo, preserving history.

* After the split, we want no services code to be in the neutron repo, with
  non-relavant history pruned.

* During the split, an infra/project-config change for the new repo, shared
  spec repo, and new core team will be created.

* The PTL will determine if any change to either core team is appropriate.

* Existing services code must be supported until deprecation.

* Existing services fixes must be backported into neutron/stable.

* The split needs to be aware of the imminent REST refactor.


Proposed Change
===============

* The repo will be split via infra scripts which will preserve history for all
  changes.

* The existing services code (e.g. lbaas v1), will move into the services repo
  and be maintained by that repo's team going forward.

* Initially, the services repo will not have its own REST service, and will
  utilize neutron extensions to share the neutron API namespace.

* The services repo will include neutron as a dependency in the
  requirements.txt file, and the services code may import neutron as a library.

* The neutron repo will have some manner of dependency specified for packaging,
  so that installs of neutron will pull in the services repo in the short-term.
  A hacking check will be added to ensure that neutron code does not import
  services code as a library.

* Extensions will stay inside the neutron repo, at least until after the REST
  refactor, which will hopefully support out-of-tree extensions.

* Code merged onto the existing 'feature/lbaasv2' neutron feature branch will
  be merged into the service repo as part of the split.

* All outstanding gerrit reviews for services, currently submitted against 
  Neutron, will have to be abandoned and resubmitted against the services repo.

* Tox will pass cleanly in both projects immediately post-split.

* The services repo will not support python 2.6.

* Backported fixes will be merged into neutron/stable branches by the
  "services" team, approved by the stable team.

* The services repo will use its own database (see Data Model Impact)

* The services repo will have its own config file.

Data Model Impact
-----------------

Services data models will be moved to the service repo, and removed from
neutron.

The services repo will have its own database migration chain.

An initial db migration state will be created by starting from the neutron db state as of the split and stripping non-service related tables.

A db migration will be added to neutron to strip service tables.

An upgrade script will be provided to migrate db data from neutron to services.


REST API Impact
---------------

The REST API will be identical before and after the split.

Security Impact
---------------

None.

Notifications Impact
--------------------

None.

Other End User Impact
---------------------

There will be a new CLI/API client, and Horizon will need to reference the new library instead of Neutron, if it is doing any direct importing.

Performance Impact
------------------

None.

Other Deployer Impact
---------------------

For two cycles, install of neutron should automatically install the advanced
services project.  When going from Icehouse or Juno to Kilo, the upgrade
script to move appropriate db and config data should be run.

* Do we need to support reading data from neutron db and config file in a lazy
  upgrade format, or as a fallback, to provide seamless upgrade?

Developer Impact
----------------

Anyone importing neutron.services will have to import the new project modules instead.

Community Impact
----------------

This split was discussed at the Neutron summit and the openstack-dev mailing
list.

Alternatives
------------

* Do nothing and keep it all in one repo.

* Services to stackforge.

* Services split with its own REST server initially.

* Services shares neutron db and config.

* Modify gerrit to allow different core teams in one repo.

Implementation
==============

Assignee(s)
-----------

Who is leading the writing of the code? Or is this a blueprint where you're
throwing it out there to see who picks it up?

If more than one person is working on the implementation, please designate the
primary author and contact.

Primary assignee:
  https://launchpad.net/~dougwig

Other contributors:
  https://launchpad.net/~mestery

Work Items
----------

* Identify files for each repo.

* Adapt olso graduation script for git split.

* Merge in feature branch.

* Adjust imports in new repo.

* Add requirements to each project.

* Add hacking rule to neutron.

* Verify or add neutron's ability to load out-of-tree service plugins.

* Create initial services db migration files.

* Neutron db migration to strip services data (to be applied later!)

* Fix references to neutron in various files (e.g. README)

* Finalize project name

* Infra patch to create new repo/group

* Get unit tests passing cleanly.

* Upgrade script to migrate db and config data.


Dependencies
============

* Infra creating separate repos.

* REST refactor not colliding at the same time.  This needs to happen before
or after.


Testing
=======

* Unit tests will split between repos, matching the code split.

* Tempest tests will initiall remain unchanged, as the service endpoint will
  be identical before and after the split.

Tempest Tests
-------------

Unchanged.

Functional Tests
----------------

Unchanged.

API Tests
---------

Unchanged.


Documentation Impact
====================

Advanced services documentation should be separated from the Neutron
documentation.

User Documentation
------------------

TBD

Developer Documentation
-----------------------

None


Q & A
=====

* Split or shared CLI/client?

* Do we take this opportunity to re-org directories?


References
==========

* https://etherpad.openstack.org/p/neutron-services

* http://lists.openstack.org/pipermail/openstack-dev/2014-November/050961.html

* Other spec?
