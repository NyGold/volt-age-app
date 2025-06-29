// Substitua todo o conteúdo do seu arquivo por este código

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// O bloco android começa aqui
android {
    namespace = "com.example.volt_age_app"
    compileSdk = flutter.compileSdkVersion

    // CORREÇÃO 1: Apenas uma definição da ndkVersion, com o valor correto.
    ndkVersion = "27.0.12077973"

    // CORREÇÃO 2: Um único bloco compileOptions, mesclando as configurações.
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // A compatibilidade com Java 8 é necessária para o desugaring.
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8" // Alinhado com a compatibilidade do Java 8
    }

    defaultConfig {
        applicationId = "com.example.volt_age_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
// O bloco android termina aqui

flutter {
    source = "../.."
}

// CORREÇÃO 3: O bloco dependencies deve estar aqui fora, no nível principal.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Suas outras dependências, como a do kotlin, podem estar aqui.
    // O plugin do flutter adiciona as dependências necessárias automaticamente.
}