pipeline {
    agent any
    triggers { pollSCM('H/5 * * * *') }
    stages {
        stage('Checkout') {
            steps {
                dir("${env.PROJECTS_DIR}/arcana-harmonyos") {
                    git url: 'https://github.com/jrjohn/arcana-harmonyos.git',
                        branch: 'main', credentialsId: 'github-credentials'
                }
            }
        }
        stage('Jest Coverage') {
            steps {
                dir("${env.PROJECTS_DIR}/arcana-harmonyos") {
                    sh 'npm install --no-fund --no-audit 2>&1 | tail -3'
                    // Copy .ets → .ts so ts-jest can handle them natively
                    sh '''
                        find entry/src/main/ets -name "*.ets" | while read f; do
                            cp "$f" "${f%.ets}.ts"
                        done
                        find entry/src/ohosTest/ets/test -name "*.ets" | while read f; do
                            cp "$f" "${f%.ets}.ts"
                        done
                    '''
                    sh 'npm run test:coverage -- --forceExit'
                    // Patch lcov: .ts paths → .ets so SonarQube matches source files
                    sh '''
                        if [ -f coverage/jest/lcov.info ]; then
                            sed -i "s|\\.ts$|.ets|g; s|\\.ts:|.ets:|g" coverage/jest/lcov.info
                        fi
                    '''
                }
            }
        }
        stage('SonarQube Analysis') {
            steps {
                dir("${env.PROJECTS_DIR}/arcana-harmonyos") {
                    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                        withSonarQubeEnv('SonarQube') {
                            sh '''sonar-scanner \
                                -Dsonar.projectKey=harmonyos-app \
                                -Dsonar.projectName="HarmonyOS App" \
                                -Dsonar.sources=entry/src/main/ets \
                                -Dsonar.javascript.file.suffixes=.js,.jsx,.ts,.tsx,.ets \
                                -Dsonar.exclusions="**/node_modules/**,**/oh_modules/**,**/build/**,**/coverage/**" \
                                -Dsonar.javascript.lcov.reportPaths=coverage/jest/lcov.info \
                                -Dsonar.scm.disabled=true'''
                        }
                    }
                }
            }
        }
    }
    post {
        success { echo "HarmonyOS Jest+SonarQube OK" }
        failure { echo "Pipeline FAILED" }
        always  { echo "Build ${BUILD_NUMBER} done" }
    }
}
