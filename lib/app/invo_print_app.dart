import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import 'di/service_locator.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_cubit.dart';

class InvoPrintApp extends StatelessWidget {
  const InvoPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const AuthSessionRequested()),
        ),
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
      ],
      child: Builder(
        builder: (context) {
          final router = createAppRouter(context.read<AuthBloc>());

          return BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp.router(
                title: 'InvoPrint',
                debugShowCheckedModeBanner: false,
                themeMode: themeState.themeMode,
                theme: AppTheme.build(
                  brightness: Brightness.light,
                  primaryColor: themeState.primaryColor,
                ),
                darkTheme: AppTheme.build(
                  brightness: Brightness.dark,
                  primaryColor: themeState.primaryColor,
                ),
                routerConfig: router,
              );
            },
          );
        },
      ),
    );
  }
}
