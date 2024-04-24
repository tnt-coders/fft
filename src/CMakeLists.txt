tnt_project__add_library(TARGET ${PROJECT_NAME}
	fourier_transform.cpp
)

target_compile_features(${PROJECT_NAME}	PUBLIC cxx_std_20)

target_compile_options(${PROJECT_NAME} PUBLIC -D_USE_MATH_DEFINES)

tnt_project__add_library(TARGET ${PROJECT_NAME}-jni SHARED
	fourier_transform_jni.cpp
)

target_link_libraries(${PROJECT_NAME}-jni
	${PROJECT_NAME}
)