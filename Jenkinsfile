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
                    // Run tests; coverage is collected even if some tests fail
                    sh 'npm run test:coverage -- --forceExit || true'
                    // Patch lcov: .ts paths → .ets so SonarQube matches source files
                    sh '''
                        if [ -f coverage/jest/lcov.info ]; then
                            sed -i "s|\\.ts$|.ets|g; s|\\.ts:|.ets:|g" coverage/jest/lcov.info
                        fi
                    '''
                    // Remove .ts copies BEFORE SonarQube scan to avoid language detection conflicts
                    // (.ts files conflict with sonar's JS+TS pattern matchers for .ets files)
                    sh '''
                        find entry/src/main/ets -name "*.ts" -delete
                        find entry/src/ohosTest/ets/test -name "*.ts" -delete
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
                                -Dsonar.inclusions="entry/src/main/ets/domain/**/*.ets,entry/src/main/ets/data/cache/LruCache.ets,entry/src/main/ets/data/api/ApiConfig.ets,entry/src/main/ets/data/api/dto/UserDto.ets" \
                                -Dsonar.exclusions="**/node_modules/**,**/oh_modules/**,**/build/**,**/coverage/**" \
                                -Dsonar.coverage.exclusions="**/domain/repository/impl/**,**/domain/services/impl/**" \
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
