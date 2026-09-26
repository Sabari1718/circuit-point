import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<LoginSubmittedEvent>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Basic validation
    if (event.username.isEmpty || event.password.isEmpty) {
      emit(const AuthFailure(message: 'Please enter both username and password'));
      return;
    }

    if (event.password.length < 6) {
      emit(const AuthFailure(message: 'Password must be at least 6 characters'));
      return;
    }

    // Success response
    emit(AuthSuccess());
  }
}
