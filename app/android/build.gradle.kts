allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox Maps SDK는 private maven repo에서 다운로드한다. 인증은
        // ~/.gradle/gradle.properties의 MAPBOX_DOWNLOADS_TOKEN(sk.* with
        // DOWNLOADS:READ scope)을 password로 전달.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = (project.findProperty("MAPBOX_DOWNLOADS_TOKEN") as String?) ?: ""
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 일부 구버전 Flutter 플러그인(예: sentry_flutter 8.x)이 Kotlin languageVersion
// 1.6을 지정하는데, 프로젝트 Kotlin 2.2가 이를 에러로 막는다("1.6 no longer
// supported; use 1.8 or greater"). 1.8 미만을 요청하는 서브프로젝트만 1.8로
// 끌어올려 컴파일을 통과시킨다(1.6 소스는 1.8 언어버전에서 그대로 컴파일됨).
// languageVersion을 명시하지 않은 플러그인은 손대지 않아 기본(2.2)을 유지.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            val min = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8
            if ((languageVersion.orNull ?: min) < min) languageVersion.set(min)
            if ((apiVersion.orNull ?: min) < min) apiVersion.set(min)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
