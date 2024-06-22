# loginitemutil

This tool was written in 2012.  Below is the mostly original README.  Of note,
this is written in Objective-C, but mostly uses CoreFoundation C APIs.  It has
been very stable, no changes were required to build this for Sonoma 14.5, and
it worked in a quick smoke test.  Including support for all users.

## Original README

The application itself is just a little wrapper around a class that I wrote
that wraps around the LSSharedFileList functions that we care about.  The
class should be fairly easy to use, and has features that system administrators
would likely care about, as well as being a simple class to use for app
developers who would just like to be able to add their own app to the login
items.

Features include:
-Setting for multiple users (requires root)
-Setting for all users (requires root)
-Making the login item Hidden (10.6+)
-Checking to see if an item exists
-Removing items
-Listing all login items
-Uses ARC and modern ObjC

The class is FFLoginItemController, and is usable in other programs, as long
as you link against OpenDirectory.framework and CoreServices.framework.

There is support for "all users" on all OS's.  Note that this support should
be considered experimental at best.  Until 10.7, there was no really good way
to find a list of all users, except to make broad assumptions and guesses.
Leopard support for this feature is very hacky, Snow Leopard is a lot better,
and Lion makes it pretty legit.  Note that there still are assumptions that
one may want to tweak when using this in a production environment.

This project is provided mainly as an instructional tool, and as such, I cannot
guarantee anything about this tool, even that it works.  Please be warned you
are using this at your own risk.
