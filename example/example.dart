library episodes.example;

import 'dart:async';
import 'dart:html';

import 'package:episodes/episodes.dart';


main() {
  new Future.value(null)
      .then((_) => mainEpisode.mark('m1'))
      .then((_) => new Future.delayed(new Duration(milliseconds: 200)))
      .then((_) => mainEpisode.mark('m2'))
      .then((_) => new Future.delayed(new Duration(milliseconds: 200)))
      .then((_) => mainEpisode.mark('m3'))
      .then((_) => new Future.delayed(new Duration(milliseconds: 200)))
      .then((_) {
        mainEpisode.mark('m4');
        mainEpisode.measure('m1..end', 'm1');
        mainEpisode.measure('m2..m3', 'm2', 'm3');
        mainEpisode.measure('m3..m4', 'm3', 'm4');
        mainEpisode.drawEpisodes(querySelector('#episodesviz'));
      });
}
