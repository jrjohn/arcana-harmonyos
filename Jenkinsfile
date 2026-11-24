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
                // No `| tail`: Jenkins sh has no pipefail, so a failed install exited 0 through the pipe.
                sh 'npm install --no-fund --no-audit'
                // A failing test fails the build: tools/run-jest.sh copies .ets → .ts, runs jest,
                // patches lcov back to .ets for Sonar, removes the copies, and exits with jest's code.
                // Same script agents run locally (AGENTS.md §5).
                sh 'bash tools/run-jest.sh'
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
                    mkdir -p arch-qube-reports
                    # Version pinned in tools/arch-qube.version (shared with tools/arch-check.sh).
                    # ghcr.io first (public, multi-arch), then arcana.boo. Never :latest — a silent
                    # fallback to latest already broke another template's CI when latest moved.
                    V="$(tr -d '[:space:]' < tools/arch-qube.version)"
                    IMG=""
                    for cand in "ghcr.io/jrjohn/arch-qube:$V" "arcana.boo/arcana/arch-qube:$V"; do
                        if docker image inspect "$cand" >/dev/null 2>&1 || docker pull -q "$cand" >/dev/null 2>&1; then
                            IMG="$cand"; break
                        fi
                    done
                    [ -n "$IMG" ] || { echo "arch-qube $V image unavailable (ghcr.io, arcana.boo) — NOT a pass"; exit 2; }
                    # Branch in the name: BUILD_NUMBER restarts at 1 on every branch, so two branches building
                    # at once used the same name and one's `docker rm -f` deleted the other's container
                    # (arcana-ios PR-14/PR-15, 2026-09-30: "destination ...:/src must be a directory").
                    AQ="arcana-arch-qube-harmonyos-$(printf '%s' "${BRANCH_NAME}-${BUILD_NUMBER}" | tr -c 'A-Za-z0-9_.-' '-')"
                    docker rm -f "$AQ" 2>/dev/null || true
                    docker create --name "$AQ" --network devops_default \
                        -v /src -v /output \
                        "$IMG" \
                        scan /src --framework harmonyos --no-ai --ci \
                        --format json,markdown -o /output --threshold 90 || exit 1
                    tar --exclude=./.git --exclude=./node_modules --exclude=./oh_modules \
                        --exclude=./coverage --exclude=./build --exclude=./entry/build --exclude=./.hvigor \
                        --exclude=./arch-qube-reports \
                        -C . -cf - . | docker cp - "$AQ":/src || exit 1
                    # set +e: Jenkins runs sh -e, so a failing scan aborted here before the report
                    # was copied out; the scan's rc is still the stage result below.
                    set +e
                    docker start -a "$AQ"
                    AQ_RC=$?
                    set -e
                    docker cp "$AQ":/output/. arch-qube-reports/ 2>/dev/null || true
                    docker rm -f "$AQ" 2>/dev/null || true
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
