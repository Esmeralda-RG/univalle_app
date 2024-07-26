import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:univalle_app/config/themes/app_colors.dart';
import 'package:univalle_app/core/providers/student_use_cases_provider.dart';
import 'package:univalle_app/features/digital_card/presentation/widgets/student_card.dart';

class DigitalCardScreen extends StatelessWidget {
  const DigitalCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
        body: SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Container(
                height: size.height * .5,
                color: AppColors.primaryRed,
              ),
              Container(
                height: size.height * .5,
                color: AppColors.white,
              )
            ],
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: size.height * .5 - (565 * .5),
                ),
              ),
              Consumer(builder: (_, ref, __) {
                return SliverToBoxAdapter(
                  child: StudentCard(
                    student: ref.watch(studentUseCasesProvider).getStudent(),
                    width: size.width * .9,
                  ),
                );
              })
            ],
          ),
          Positioned(
            top: 10,
            right: 20,
            child: SafeArea(
              child: IconButton(
                  style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      shadowColor: AppColors.grey,
                      elevation: 5,
                      backgroundColor: AppColors.white),
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.primaryRed,
                  )),
            ),
          )
        ],
      ),
    ));
  }
}
