
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:music/bottom_controls.dart';
import 'package:music/songs.dart';
import 'package:music/theme.dart';
import 'package:fluttery/gestures.dart';
import 'package:fluttery_audio/fluttery_audio.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  MyApp();

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fluttery Player',
      home: new _MyHomePage(),
    );
  }
}

class _MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<_MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return AudioPlaylist(
      playlist: demoPlaylist.songs.map((DemoSong song) {
        return song.audioUrl;
      }).toList(growable: false),
      playbackState: PlaybackState.paused,
      child: new Scaffold(
        appBar: new AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: () {
              //TODO
            },
            color: Colors.grey[350],
          ),
          actions: <Widget>[
            new IconButton(
              icon: new Icon(Icons.menu),
              onPressed: () {
                //TODO
              },
              color: Colors.grey[350],
            ),
          ],
          title: new Text(''),
        ),
        body: new Column(
          children: <Widget>[
            // seek bar
            new Expanded(child: new AudioPlaylistComponent(
              playlistBuilder:
                  (BuildContext context, Playlist playlist, Widget child) {
                String albumArtUrl =
                    demoPlaylist.songs[playlist.activeIndex].albumArtUrl;
                return new AudioRadialSeekBar(albumArtUrl: albumArtUrl);
              },
            )),

            // visualizer
            new Container(
              width: double.infinity,
              height: 125.0,

              // Visualizer from fluttery_audio
              child: new Visualizer(
                builder: (BuildContext context, List<int> fft) {
                  return new CustomPaint(
                    painter: new VisualizerPainter(
                        fft: fft, color: accentColor, height: 125.0),
                    child: new Container(),
                  );
                },
              ),
            ),

            //song track and title
            new BottomControls()
          ],
        ),
      ),
    );
  }
}

class VisualizerPainter extends CustomPainter {
  final List<int> fft;
  final Color color;
  final double height;
  final Paint wavePaint;

  VisualizerPainter({this.fft, this.color, this.height}):
      wavePaint = new Paint()
  ..color=color.withOpacity(0.5)
  ..style=PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _renderWaves(canvas, size);
  }

  void _renderWaves(Canvas canvas, Size size){
    final histogramLow = _createHistogram(fft, 15,2,((fft.length/4).floor()));
    final histogramHigh = _createHistogram(fft, 15,((fft.length)/4).ceil(),((fft.length)/2).floor());

    _renderHistogram(canvas,size,histogramLow);
    _renderHistogram(canvas,size,histogramHigh);

  }

  void _renderHistogram(Canvas canvas , Size size, List<int> histogram){

    if(histogram.length==0){
      return;
    }
    final pointsToGraph = histogram.length;
    final widthPerSample = (size.width/(pointsToGraph-2)).floor();

    final points = new List<double>.filled(pointsToGraph*4, 0.0);

    for (int i = 0; i < histogram.length - 1; ++i) {
      points[i * 4] = (i * widthPerSample).toDouble();
      points[i * 4 + 1] = size.height - histogram[i].toDouble();

      points[i * 4 + 2] = ((i + 1) * widthPerSample).toDouble();
      points[i * 4 + 3] = size.height - (histogram[i + 1].toDouble());
    }

    Path path = new Path();
    path.moveTo(0.0, size.height);
    path.lineTo(points[0], points[1]);
    for (int i = 2; i < points.length - 4; i += 2) {
      path.cubicTo(
          points[i - 2] + 10.0, points[i - 1],
          points[i] - 10.0, points [i + 1],
          points[i], points[i + 1]
      );
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  List<int> _createHistogram(List<int> samples,int bucketCount,[int start, int end]){
    if(start==end){
      return const[];
    }
    start = start??0;
    end = end??samples.length-1;

    final sampleCount = end -start +1;
    final samplePerBucket = (sampleCount/bucketCount).floor();
    if(samplePerBucket==0){
      return const[];
    }

    final actualSampleCount = sampleCount - (sampleCount%samplePerBucket);

    List<int> histogram = new List<int>.filled(bucketCount, 0);

    for (int i =start ; i<=start+actualSampleCount;i++){

      // ignoring imaginary part
      if((i-start)%2==1){
        continue;
      }

      int bucketIndex = ((i-start)/samplePerBucket).floor();
      histogram[bucketIndex]+=samples[i];
    }

    for (int i =0;i<histogram.length;i++){
      histogram[i]=(histogram[i]/samplePerBucket).abs().round();
    }
    return histogram;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class RadialProgressBar extends StatefulWidget {
  final double trackWidth;
  final Color trackColor;
  final double progressWidth;
  final Color progressColor;
  final double progressPercentage;
  final double thumbSize;
  final Color thumbColor;
  final double thumbPosition;
  final EdgeInsets outPadding;
  final EdgeInsets inPadding;

  final Widget child;

  RadialProgressBar(
      {this.trackWidth = 3.0,
      this.trackColor = Colors.grey,
      this.progressWidth = 5.0,
      this.progressColor = darkAccentColor,
      this.progressPercentage = 0.0,
      this.thumbSize = 10.0,
      this.thumbColor = darkAccentColor,
      this.thumbPosition = 0.0,
      this.outPadding = const EdgeInsets.all(0.0),
      this.inPadding = const EdgeInsets.all(0.0),
      this.child});

  @override
  _RadialProgressBarState createState() => _RadialProgressBarState();
}

class _RadialProgressBarState extends State<RadialProgressBar> {
  EdgeInsets _insetsForPainter() {
    /*
    * Make room for painted track, progress, and thumb. We divide by 2.0 because
    * we want to allow flush painting against track, so we need to account the thickness
    * outside the track , not inside
    * */

    final outThickness =
        max(widget.trackWidth, max(widget.thumbSize, widget.progressWidth)) /
            2.0;
    return new EdgeInsets.all(outThickness);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.outPadding,
      child: new CustomPaint(
        foregroundPainter: new RadialSeekBarPainter(
            trackColor: widget.trackColor,
            trackWidth: widget.trackWidth,
            progressColor: widget.progressColor,
            progressPercentage: widget.progressPercentage,
            progressWidth: widget.progressWidth,
            thumbColor: widget.thumbColor,
            thumbPosition: widget.thumbPosition,
            thumbSize: widget.thumbSize),
        child: new Padding(
          padding: _insetsForPainter() + widget.inPadding,
          child: widget.child, // child is album art
        ),
      ),
    );
  }
}

class RadialSeekBarPainter extends CustomPainter {
  final double trackWidth;
  Color trackColor;
  final Paint trackPaint;
  final double progressWidth;
  Color progressColor;
  final double progressPercentage;
  final Paint progressPaint;
  final double thumbSize;
  Color thumbColor;
  final double thumbPosition;
  final Paint thumbPaint;

  RadialSeekBarPainter(
      {@required this.trackWidth,
      @required trackColor,
      @required this.progressWidth,
      @required progressColor,
      @required this.progressPercentage,
      @required this.thumbSize,
      @required thumbColor,
      @required this.thumbPosition})
      : trackPaint = new Paint()
          ..color = trackColor
          ..strokeWidth = trackWidth
          ..style = PaintingStyle.stroke,
        progressPaint = new Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = progressWidth
          ..color = progressColor
          ..strokeCap = StrokeCap.round,
        thumbPaint = new Paint()
          ..color = thumbColor
          ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final outThickness = max(trackWidth, max(progressWidth, thumbSize));

    final constrainedSize =
        new Size(size.width - outThickness, size.height - outThickness);

    final center = new Offset(size.height / 2, size.width / 2);
    final radius = min(constrainedSize.width, constrainedSize.height) / 2;

    // Paint Track
    canvas.drawCircle(center, radius, trackPaint);

    //Paint Progress
    final progressAngle =
        2 * pi * progressPercentage; // with reference to start angle

    canvas.drawArc(new Rect.fromCircle(center: center, radius: radius), -pi / 2,
        progressAngle, false, progressPaint);

    //Paint thumb
    final thumbAngle = 2 * pi * thumbPosition - pi / 2; // Absolute Angle
    final thumbX = cos(thumbAngle) * radius;
    final thumbY = sin(thumbAngle) * radius;
    final thumbCenter = new Offset(thumbX, thumbY) + center;
    canvas.drawCircle(thumbCenter, thumbSize / 2, thumbPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class RadialSeekBar extends StatefulWidget {
  final double seekPercent;
  final double progress;
  final Function(double) onSeekRequested;
  final Widget child;

  RadialSeekBar(
      {this.progress = 0.0,
      this.seekPercent = 0.0,
      this.onSeekRequested,
      this.child});

  @override
  _RadialSeekBarState createState() => _RadialSeekBarState();
}

class _RadialSeekBarState extends State<RadialSeekBar> {
  double _progress = 0.0;
  PolarCoord _startDragCoord;
  double _startDragPercent;
  double _currentDragPercent;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
  }

  @override
  void didUpdateWidget(RadialSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress = widget.progress;
  }

  void _onRadialDragStart(PolarCoord coord) {
    _startDragCoord = coord;
    _startDragPercent = _progress;
  }

  void _onRadialDragUpdate(PolarCoord coord) {
    final dragAngle = coord.angle - _startDragCoord.angle;
    final dragPercent = dragAngle / (2 * pi);

    setState(
        () => _currentDragPercent = (_startDragPercent + dragPercent) % 1.0);
  }

  void _onRadialDragEnd() {
    if (widget.onSeekRequested != null) {
      widget.onSeekRequested(_currentDragPercent);
    }
    setState(() {
      _currentDragPercent = null;
      _startDragCoord = null;
      _startDragPercent = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    double thumbPosition = _progress;

    // user is dragging
    if (_currentDragPercent != null) {
      thumbPosition = _currentDragPercent;
    } else if (widget.seekPercent != null) {
      thumbPosition = widget.seekPercent;
    }

    // RadialDragGestureDetector from fluttery
    return new RadialDragGestureDetector(
      onRadialDragStart: _onRadialDragStart,
      onRadialDragUpdate: _onRadialDragUpdate,
      onRadialDragEnd: _onRadialDragEnd,
      child: new Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: new Center(
          child: new Container(
            width: 140.0,
            height: 140.0,
            child: new RadialProgressBar(
              trackColor: const Color(0xFFDDDDDD),
              progressPercentage: _progress,
              progressColor: accentColor,
              thumbPosition: thumbPosition,
              thumbColor: lightAccentColor,
              inPadding: const EdgeInsets.all(10.0),
              child: new ClipOval(
                clipper: new CircleClipper(),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AudioRadialSeekBar extends StatefulWidget {
  final String albumArtUrl;

  AudioRadialSeekBar({this.albumArtUrl});

  @override
  _AudioRadialSeekBarState createState() => _AudioRadialSeekBarState();
}

class _AudioRadialSeekBarState extends State<AudioRadialSeekBar> {
  double _seekPercent;

  @override
  Widget build(BuildContext context) {
    return new AudioComponent(
      updateMe: [
        WatchableAudioProperties.audioPlayhead,
        WatchableAudioProperties.audioSeeking
      ],
      playerBuilder: (BuildContext context, AudioPlayer player, Widget child) {
        double playBackProgress = 0.0;

        if (player.audioLength != null && player.position != null) {
          playBackProgress = player.position.inMilliseconds /
              player.audioLength.inMilliseconds;
        }

        _seekPercent = player.isSeeking ? _seekPercent : null;

        return new RadialSeekBar(
            progress: playBackProgress,
            seekPercent: _seekPercent,
            onSeekRequested: (double seekPercent) {
              setState(() => _seekPercent = seekPercent);
              final seekInMillis =
                  (player.audioLength.inMilliseconds * seekPercent).round();

              player.seek(new Duration(milliseconds: seekInMillis));
            },
            child: new Container(
              color: accentColor,
              child: new Image.network(
                widget.albumArtUrl,
                fit: BoxFit.cover,
              ),
            ));
      },
    );
  }
}

class CircleClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return new Rect.fromCircle(
      center: new Offset(size.width / 2, size.height / 2),
      radius: min(size.width, size.height) / 2,
    );
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}
