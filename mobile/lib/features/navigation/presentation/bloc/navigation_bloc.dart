import 'package:flutter_bloc/flutter_bloc.dart';

// EVENEMENTS : Ce que l'utilisateur fait
abstract class NavigationEvent {}

class TabChanged extends NavigationEvent {
  final int index;
  TabChanged(this.index);
}

// ETATS : Ce que l'application affiche
class NavigationState {
  final int currentIndex;
  NavigationState(this.currentIndex);
}

// LE BLOC : Le cerveau qui fait le lien
class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc() : super(NavigationState(0)) {
    on<TabChanged>((event, emit) {
      emit(NavigationState(event.index));
    });
  }
}
