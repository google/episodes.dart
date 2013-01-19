Episodes
========

A framework for timing performance of web apps. This package contains libraries
to measure timing metrics in web applications. You can use it to measure
something small entirely on the client side, or you can use it to send beacons
to a server and gather end-to-end measurements of your application.

This library is a port of Steve Souders's [Episodes JS library][episodes] with
some additional modifications and additions of our own.

## Using Episodes

Add the `episodes` package to your pubspec.yaml file, selecting a version range
that works with your version of the SDK. For example:

```yaml
dependencies:
  episodes: ">=0.3.0 <0.3.1"
```

Then you can directly import the episodes library via
`packages:episodes/episodes.dart`. This library exposes the `Episodes` class,
which contains methods you can use to instrument your code.

You can call mark() to mark points in time, or call measure() to record
intervals between two such points. You can later extract the results a graphical
timeline in HTML, as HTML tables, or you can send them to a listener via
window.postMessage.

There is an associated Reporter class for listening to the window.postMessage
notifications. This can be customized in suitable ways. For example, the default
case is like the original episodes library; there is also a [Yahoo
Boomerang][boomerang] compatible reporter available.

# A note about versions

The episode package follows [semantic versioning][semver]. Prior to 1.0, we
follow a similar scheme to semantic versioning.  We treat the 'patch' number as
the 'minor' version, and use + as a patch. So a change from 0.3.0 to 0.3.0+1 is
a non-breaking change, but a change from 0.3.0 to 0.3.1 is considered a breaking
change. Additionally we try to match the minor version with the current
milestone from the Dart SDK. The first release of episodes is versioned as 0.3.0
because it was developed under the first M3 release of the Dart SDK. If Dart M4
has breaking changes, our library at that point will jump to version 0.4.

[episodes]: http://stevesouders.com/episodes/
[boomerang]: http://yahoo.github.com/boomerang/doc/
[semver]: http://semver.org/
