// Jenkinsfile — multibranch pipeline for arcana-harmonyos
// Adapted from the existing single-branch pipeline (Jest + SonarQube + Arch Qube,
// which was driven by the legacy harmonyos-app-pipeline CpsScmFlowDefinition
// pointing at this same Jenkinsfile).
//
// Key differences from the previous single-branch version:
//   * `checkout scm` (no hardcoded branch=main)        — supports every branch + every PR
//   * `pollSCM` trigger removed                        — Jenkins multibranch + GitHub webhook drive triggers
//   * `dir("${env.PROJECTS_DIR}/arcana-harmonyos")` blocks REMOVED — multibranch uses workspace root
//   * Real blocking gates: Jest/SonarQube/Arch-Qube failures fail the build
//     (no catchError swallow); SonarQube quality gate polled via API and enforced
//   * Arch Qube Metrics push gated `when { branch 'main' }` — PR builds skip metrics push

pipeline {
    agent any

    options {
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '1'))
        timestamps()
    }

    environment {
        PROJECT_NAME = "harmonyos-app"
        APP_NAME     = "harmonyos-app"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
                script {
                    echo "Branch: ${env.BRANCH_NAME ?: 'unknown'}"
                    echo "PR: ${env.CHANGE_ID ?: 'no'} (target: ${env.CHANGE_TARGET ?: 'n/a'})"
                }
            }
        }

        stage("Cleanup Old Images") {
            steps {
                sh '''
                    # Remove dangling/unused images to free disk space
                    docker image prune -f || true
                    # Keep only last 3 build-tagged images for this app
                    docker images --format '{{.Repository}}:{{.Tag}}' \
                        | grep "${APP_NAME}.*build-" \
                        | sort -t- -k2 -rn \
                        | tail -n +4 \
                        | xargs -r docker rmi 2>/dev/null || true
                '''
            }
        }

        stage('Jest Coverage') {
            steps {
                sh 'npm install --no-fund --no-audit 2>&1 | tail -3'
                // A failing test now fails the build (real gate). RC is captured so the
                // lcov patch + .ts cleanup still run, then we exit with the test result.
                sh '''
                    set +e
                    # Copy .ets → .ts so ts-jest can handle them natively
                    find entry/src/main/ets -name "*.ets" | while read f; do
                        cp "$f" "${f%.ets}.ts"
                    done
                    find entry/src/ohosTest/ets/test -name "*.ets" | while read f; do
                        cp "$f" "${f%.ets}.ts"
                    done
                    npm run test:coverage -- --forceExit
                    RC=$?
                    # Patch lcov: .ts paths → .ets so SonarQube matches source files
                    if [ -f coverage/jest/lcov.info ]; then
                        sed -i "s|\\.ts$|.ets|g; s|\\.ts:|.ets:|g" coverage/jest/lcov.info
                    fi
                    # Remove .ts copies BEFORE SonarQube scan to avoid language detection
                    # conflicts (.ts files conflict with sonar's JS+TS matchers for .ets).
                    find entry/src/main/ets -name "*.ts" -delete
                    find entry/src/ohosTest/ets/test -name "*.ts" -delete
                    exit $RC
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    // SonarQube Community Build rejects sonar.pullrequest.*
                    // (Developer Edition feature), so PR builds run a plain scan
                    // without GitHub PR decoration.
                    sh """sonar-scanner \
                        -Dsonar.projectKey=harmonyos-app \
                        -Dsonar.projectName="HarmonyOS App" \
                        -Dsonar.sources=entry/src/main/ets \
                        -Dsonar.inclusions="entry/src/main/ets/domain/**/*.ets,entry/src/main/ets/data/cache/LruCache.ets,entry/src/main/ets/data/api/ApiConfig.ets,entry/src/main/ets/data/api/dto/UserDto.ets" \
                        -Dsonar.exclusions="**/node_modules/**,**/oh_modules/**,**/build/**,**/coverage/**" \
                        -Dsonar.coverage.exclusions="**/domain/repository/impl/**,**/domain/services/impl/**" \
                        -Dsonar.javascript.lcov.reportPaths=coverage/jest/lcov.info \
                        -Dsonar.scm.disabled=true"""
                    sh '''
                        set -e
                        TOKEN="${SONAR_AUTH_TOKEN:-$SONAR_TOKEN}"
                        RT=.scannerwork/report-task.txt
                        [ -f "$RT" ] || { echo "report-task.txt missing"; exit 1; }
                        CE_TASK_ID=$(grep '^ceTaskId=' "$RT" | cut -d= -f2-)
                        ANALYSIS_ID=""
                        for i in $(seq 1 60); do
                            RESP=$(curl -s -u "$TOKEN:" "$SONAR_HOST_URL/api/ce/task?id=$CE_TASK_ID")
                            ST=$(echo "$RESP" | grep -o '"status":"[A-Z_]*"' | head -1 | cut -d'"' -f4)
                            echo "  CE status: ${ST:-?} (try $i)"
                            if [ "$ST" = "SUCCESS" ]; then ANALYSIS_ID=$(echo "$RESP" | grep -o '"analysisId":"[^"]*"' | head -1 | cut -d'"' -f4); break;
                            elif [ "$ST" = "FAILED" ] || [ "$ST" = "CANCELED" ]; then echo "CE $ST"; exit 1; fi
                            sleep 5
                        done
                        [ -n "$ANALYSIS_ID" ] || { echo "CE timeout"; exit 1; }
                        GATE=$(curl -s -u "$TOKEN:" "$SONAR_HOST_URL/api/qualitygates/project_status?analysisId=$ANALYSIS_ID")
                        GST=$(echo "$GATE" | grep -o '"status":"[A-Z]*"' | head -1 | cut -d'"' -f4)
                        echo "Quality gate: ${GST:-UNKNOWN}"
                        if [ "$GST" != "OK" ]; then echo "$GATE"; exit 1; fi
                    '''
                }
            }
        }

        stage("Architecture Qube") {
            steps {
                // This Jenkins talks to the HOST docker daemon, so a -v $(pwd):/project
                // bind mount resolves to a stray host path (empty /project). Stage the
                // workspace into the container via docker cp instead, and gate on the
                // scan exit code (threshold 90).
                sh '''
                    docker rm -f arcana-arch-qube-harmonyos 2>/dev/null || true
                    docker create --name arcana-arch-qube-harmonyos --network devops_default \
                        -v /src -v /output \
                        arcana.boo/arcana/arch-qube:latest \
                        scan /src --framework harmonyos --no-ai --ci \
                        --format json,markdown -o /output --threshold 90 || exit 1
                    tar --exclude=./.git --exclude=./node_modules --exclude=./oh_modules \
                        --exclude=./coverage --exclude=./build --exclude=./arch-qube-reports \
                        -C . -cf - . | docker cp - arcana-arch-qube-harmonyos:/src || exit 1
                    docker start -a arcana-arch-qube-harmonyos
                    AQ_RC=$?
                    mkdir -p arch-qube-reports
                    docker cp arcana-arch-qube-harmonyos:/output/. arch-qube-reports/ 2>/dev/null || true
                    docker rm -f arcana-arch-qube-harmonyos 2>/dev/null || true
                    exit $AQ_RC
                '''
            }
        }

        stage("Arch Qube Metrics") {
            // PR builds skip pushing metrics to pushgateway — only main publishes.
            when { branch 'main' }
            steps {
                catchError(buildResult: 'SUCCESS', stageResult: 'SUCCESS') {
                    sh '''
                        if [ -f arch-qube-reports/arch-qube.json ]; then
                            python3 -c '
import json
d=json.load(open("arch-qube-reports/arch-qube.json"))
s=d["score"]["total"];v=d["summary"]["total_violations"]
p=1 if d["score"]["pass"] else 0;fw=d["meta"]["framework"]
proj="arcana-harmonyos"
m=""
m+="arch_qube_score{project=\\"%s\\",framework=\\"%s\\"} %s\\n" % (proj,fw,s)
m+="arch_qube_violations{project=\\"%s\\",framework=\\"%s\\"} %s\\n" % (proj,fw,v)
m+="arch_qube_passed{project=\\"%s\\",framework=\\"%s\\"} %s\\n" % (proj,fw,p)
for r in d["rules"]:
    m+="arch_qube_rule_compliance{project=\\"%s\\",rule=\\"%s\\"} %s\\n" % (proj,r["id"],r["compliance"])
open("/tmp/aq.txt","w").write(m)
'
                            docker run --rm --network devops_default \\
                                -v /tmp/aq.txt:/m.txt curlimages/curl:latest \\
                                -s -X POST --data-binary @/m.txt \\
                                http://pushgateway:9091/metrics/job/arch_qube/project/arcana-harmonyos || true
                        fi
                    '''
                }
            }
        }
    }

    post {
        success { echo "HarmonyOS build SUCCESS: ${PROJECT_NAME} branch=${env.BRANCH_NAME ?: '?'} pr=${env.CHANGE_ID ?: 'no'}" }
        failure { echo "HarmonyOS build FAILED: ${PROJECT_NAME} branch=${env.BRANCH_NAME ?: '?'} pr=${env.CHANGE_ID ?: 'no'}" }
        always  { echo "Build ${BUILD_NUMBER} done" }
    }
}
