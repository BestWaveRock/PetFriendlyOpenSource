# IPA 版本公告

IPA 上传成功后，由 CI 的 iOS Job 执行。版本直接读取构建阶段生成的
`${ARTIFACT_DIR:-${WORKSPACE:-.}/artifacts}/last_built_version.txt`，MySQL 驱动会自动从 Maven 本地仓库（`${M2_REPO:-$HOME/.m2}`，可用 `MYSQL_CONNECTOR_JAR` 直接指定）查找：

```bash
sh script/release/publish_release_notice.sh
```

数据库连接通过 `RELEASE_DB_URL`、`RELEASE_DB_USER`、`RELEASE_DB_PASSWORD` 环境变量注入。
`remark=release:<版本>` 保证重复构建不会重复发公告。

公告属于 IPA 上传后的附属步骤，不应把已成功上传的 IPA 标记为打包失败。声明式流水线建议：

```groovy
stage('release_notice') {
  steps {
    catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
      withCredentials([
        string(credentialsId: 'DB_URL', variable: 'RELEASE_DB_URL'),
        usernamePassword(credentialsId: 'DB_ACCOUNT', usernameVariable: 'RELEASE_DB_USER', passwordVariable: 'RELEASE_DB_PASSWORD')
      ]) {
        sh 'sh script/release/publish_release_notice.sh'
      }
    }
  }
}
```
