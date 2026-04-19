pipeline {
  agent any

  options {
    timestamps()
  }

  environment {
    BUNDLE_PATH = 'vendor/bundle'
    AVF_KEEP_FAILURE_ARTIFACTS = '1'
    AVF_ACCEPTANCE_ROOT = "${WORKSPACE}/build/acceptance/linux-matrix"
  }

  stages {
    stage('Verify Host') {
      steps {
        sh '''
          set -euo pipefail

          test "$(uname -s)" = "Darwin"
          test "$(uname -m)" = "arm64"
          command -v vagrant >/dev/null 2>&1
          command -v docker >/dev/null 2>&1
          command -v xcrun >/dev/null 2>&1
        '''
      }
    }

    stage('Bundle') {
      steps {
        sh '''
          set -euo pipefail
          bundle install
        '''
      }
    }

    stage('Release Confidence') {
      steps {
        sh '''
          set -euo pipefail
          scripts/release-confidence
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'build/boxes/*.box, build/boxes/*.sha256, build/acceptance/**/*', allowEmptyArchive: true, fingerprint: true
    }
  }
}
