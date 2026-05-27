allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 1º: Configuramos a injeção do namespace (nosso bloco)
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            val method = androidExtension.javaClass.getMethod("getNamespace")
            val currentNamespace = method.invoke(androidExtension)
            if (currentNamespace == null) {
                val setNamespaceMethod = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                setNamespaceMethod.invoke(androidExtension, group.toString())
            }
        }
    }
}

// 2º: AGORA SIM o Gradle pode avaliar o projeto (esta linha tem que ser a última dos subprojects)
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}