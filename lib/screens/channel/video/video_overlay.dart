import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/constants.dart';
import 'package:frosty/main.dart';
import 'package:frosty/screens/channel/video/video_store.dart';
import 'package:frosty/widgets/button.dart';
import 'package:frosty/widgets/dialog.dart';
import 'package:frosty/widgets/profile_picture.dart';
import 'package:intl/intl.dart';

import '../../../widgets/modal.dart';
import '../chat/details/chat_users_list.dart';
import '../chat/stores/chat_store.dart';

/// Creates a widget containing controls which enable interactions with an underlying [Video] widget.
class VideoOverlay extends StatelessWidget {
  final VideoStore videoStore;
  final ChatStore chatStore;
  final void Function() onSettingsPressed;
  final void Function() onBackPressed;

  const VideoOverlay({
    Key? key,
    required this.videoStore,
    required this.chatStore,
    required this.onSettingsPressed,
    required this.onBackPressed,
  }) : super(key: key);

  Future<void> _showSleepTimerDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => FrostyDialog(
        title: 'Sleep Timer',
        content: Observer(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer),
                  Text(' ${videoStore.timeRemaining.toString().split('.')[0]}'),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cancel sleep timer',
                    onPressed: videoStore.sleepTimer != null && videoStore.sleepTimer!.isActive ? videoStore.cancelSleepTimer : null,
                    icon: const Icon(Icons.cancel),
                  ),
                ],
              ),
              Row(
                children: [
                  DropdownButton(
                    value: videoStore.sleepHours,
                    items: List.generate(24, (index) => index).map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (int? hours) => videoStore.sleepHours = hours!,
                    menuMaxHeight: 200,
                  ),
                  const SizedBox(width: 10.0),
                  const Text('Hours'),
                ],
              ),
              Row(
                children: [
                  DropdownButton(
                    value: videoStore.sleepMinutes,
                    items: List.generate(60, (index) => index).map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (int? minutes) => videoStore.sleepMinutes = minutes!,
                    menuMaxHeight: 200,
                  ),
                  const SizedBox(width: 10.0),
                  const Text('Minutes'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Observer(
            builder: (context) => Button(
              onPressed: videoStore.sleepHours == 0 && videoStore.sleepMinutes == 0
                  ? null
                  : () => videoStore.updateSleepTimer(
                        onTimerFinished: () => navigatorKey.currentState?.popUntil((route) => route.isFirst),
                      ),
              child: const Text('Set Timer'),
            ),
          ),
          Button(
            onPressed: Navigator.of(context).pop,
            fill: true,
            color: Colors.red.shade700,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    final backButton = Align(
      alignment: Alignment.topLeft,
      child: IconButton(
        tooltip: 'Back',
        icon: Icon(
          Icons.adaptive.arrow_back,
          color: Colors.white,
        ),
        onPressed: onBackPressed,
      ),
    );

    final settingsButton = IconButton(
      tooltip: 'Settings',
      icon: const Icon(
        Icons.settings,
        color: Colors.white,
      ),
      onPressed: onSettingsPressed,
    );

    final chatOverlayButton = Observer(
      builder: (_) => IconButton(
        tooltip: videoStore.settingsStore.fullScreenChatOverlay ? 'Hide chat overlay' : 'Show chat overlay',
        onPressed: () => videoStore.settingsStore.fullScreenChatOverlay = !videoStore.settingsStore.fullScreenChatOverlay,
        icon: videoStore.settingsStore.fullScreenChatOverlay ? const Icon(Icons.chat_bubble_outline) : const Icon(Icons.chat_bubble),
        color: Colors.white,
      ),
    );

    final refreshButton = IconButton(
      tooltip: 'Refresh',
      icon: const Icon(
        Icons.refresh,
        color: Colors.white,
      ),
      onPressed: videoStore.handleRefresh,
    );

    final fullScreenButton = IconButton(
      tooltip: videoStore.settingsStore.fullScreen ? 'Exit fullscreen mode' : 'Enter fullscreen mode',
      icon: videoStore.settingsStore.fullScreen
          ? const Icon(
              Icons.fullscreen_exit,
              color: Colors.white,
            )
          : const Icon(
              Icons.fullscreen,
              color: Colors.white,
            ),
      onPressed: () => videoStore.settingsStore.fullScreen = !videoStore.settingsStore.fullScreen,
    );

    final sleepTimerButton = IconButton(
      tooltip: 'Sleep timer',
      icon: const Icon(
        Icons.timer,
        color: Colors.white,
      ),
      onPressed: () => _showSleepTimerDialog(context),
    );

    final rotateButton = IconButton(
      tooltip: orientation == Orientation.portrait ? 'Enter landscape mode' : 'Exit landscape mode',
      icon: const Icon(
        Icons.screen_rotation,
        color: Colors.white,
      ),
      onPressed: () {
        if (orientation == Orientation.portrait) {
          if (Platform.isIOS) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeRight,
            ]);
            SystemChrome.setPreferredOrientations([]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeRight,
              DeviceOrientation.landscapeLeft,
            ]);
          }
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
          SystemChrome.setPreferredOrientations([]);
        }
      },
    );

    final streamInfo = videoStore.streamInfo;
    if (streamInfo == null) {
      return Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              backButton,
              const Spacer(),
              if (videoStore.settingsStore.fullScreen && orientation == Orientation.landscape) chatOverlayButton,
              settingsButton,
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                refreshButton,
                if (!videoStore.isIPad) rotateButton,
                if (orientation == Orientation.landscape) fullScreenButton,
              ],
            ),
          ),
        ],
      );
    }

    final streamerName = regexEnglish.hasMatch(streamInfo.userName) ? streamInfo.userName : '${streamInfo.userName} (${streamInfo.userLogin})';
    final streamer = Row(
      children: [
        ProfilePicture(
          userLogin: streamInfo.userLogin,
          radius: 10.0,
        ),
        const SizedBox(width: 5.0),
        Flexible(
          child: Tooltip(
            message: streamerName,
            preferBelow: false,
            child: Text(
              streamerName,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );

    final brightnessSlider = Flexible(
      flex: 1,
      child: GestureDetector(
        onTap: () => videoStore.handleVideoTap(),
        onVerticalDragUpdate: MediaQuery.of(context).orientation == Orientation.landscape
            ? (update) {
                videoStore.handleBrightnessGesture(update.primaryDelta!);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.3),
          child: Observer(builder: (_) {
            return Center(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  reverseDuration: const Duration(milliseconds: 500),
                  child: videoStore.showBrightnessUI
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sunny, color: Colors.white, size: 32),
                            const SizedBox(width: 12),
                            Text(
                              '${videoStore.currentBrightnessPercentage}%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 36, letterSpacing: 0.2, fontFamily: 'Product Sans', fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Container()),
            );
          }),
        ),
      ),
    );

    final volumeSlider = Flexible(
      flex: 1,
      child: GestureDetector(
        onTap: () => videoStore.handleVideoTap(),
        onVerticalDragUpdate: MediaQuery.of(context).orientation == Orientation.landscape
            ? (update) {
                videoStore.handleVolumeGesture(update.primaryDelta!);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.3),
          child: Observer(builder: (_) {
            return Center(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  reverseDuration: const Duration(milliseconds: 500),
                  child: videoStore.showVolumeUI
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.volume_up, color: Colors.white, size: 32),
                            const SizedBox(width: 12),
                            Text(
                              '${videoStore.currentVolumePercentage}%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 36, letterSpacing: 0.2, fontFamily: 'Product Sans', fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Container()),
            );
          }),
        ),
      ),
    );

    return Observer(
      builder: (context) {
        return Stack(
          children: [
            // brightness and volume sliders at the bottom of the stack
            Flex(
              direction: Axis.horizontal,
              children: [brightnessSlider, volumeSlider],
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                backButton,
                const Spacer(),
                if (videoStore.settingsStore.fullScreen && orientation == Orientation.landscape) chatOverlayButton,
                sleepTimerButton,
                settingsButton,
              ],
            ),

            // Add a play button when paused for Android
            // When an ad is paused on Android there is no way to unpause, so a play button is necessary.
            if (Platform.isAndroid)
              Center(
                child: IconButton(
                  tooltip: videoStore.paused ? 'Play' : 'Pause',
                  iconSize: 50.0,
                  icon: videoStore.paused
                      ? const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                        )
                      : const Icon(
                          Icons.pause,
                          color: Colors.white,
                        ),
                  onPressed: videoStore.handlePausePlay,
                ),
              )
            else if (videoStore.paused)
              Center(
                child: IconButton(
                  tooltip: 'Pause',
                  iconSize: 50.0,
                  icon: const Icon(
                    Icons.pause,
                    color: Colors.white,
                  ),
                  onPressed: videoStore.handlePausePlay,
                ),
              ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: videoStore.handleExpand,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: videoStore.settingsStore.expandInfo
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  streamer,
                                  const SizedBox(height: 5.0),
                                  Tooltip(
                                    message: videoStore.streamInfo!.title.trim(),
                                    preferBelow: false,
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(
                                      videoStore.streamInfo!.title.trim(),
                                      maxLines: orientation == Orientation.portrait ? 1 : 5,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5.0),
                                  GestureDetector(
                                    onTap: () => showModalBottomSheet(
                                      backgroundColor: Colors.transparent,
                                      isScrollControlled: true,
                                      context: context,
                                      builder: (context) => FrostyModal(
                                        child: SizedBox(
                                          height: MediaQuery.of(context).size.height * 0.8,
                                          child: GestureDetector(
                                            onTap: FocusScope.of(context).unfocus,
                                            child: ChattersList(
                                              chatDetailsStore: chatStore.chatDetailsStore,
                                              chatStore: chatStore,
                                              userLogin: chatStore.channelName,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: Observer(builder: (_) {
                                      return Text(
                                        '${videoStore.streamInfo!.gameName.isNotEmpty ? videoStore.streamInfo?.gameName : 'No Category'} \u2022 ${NumberFormat().format(videoStore.streamInfo?.viewerCount)} viewers - ${DateTime.now().difference(DateTime.parse(videoStore.streamInfo!.startedAt)).toString().split('.')[0]}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              )
                            : streamer,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Picture-in-picture',
                    icon: const Icon(
                      Icons.picture_in_picture_alt_rounded,
                      color: Colors.white,
                    ),
                    onPressed: videoStore.requestPictureInPicture,
                  ),
                  refreshButton,
                  if (!videoStore.isIPad) rotateButton,
                  if (orientation == Orientation.landscape) fullScreenButton,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
