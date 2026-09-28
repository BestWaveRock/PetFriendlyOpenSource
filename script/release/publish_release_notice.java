import java.nio.file.*;
import java.sql.*;

/** Run after the IPA has been uploaded successfully. */
class publish_release_notice {
    /** 公告表名与默认租户，按你自己的表结构调整 */
    private static final String NOTICE_TABLE = "your_notice_table";
    private static final String DEFAULT_TENANT = "your_tenant_id";

    public static void main(String[] args) throws Exception {
        if (args.length != 2) throw new IllegalArgumentException("usage: VERSION NOTES_FILE");
        String version = args[0].trim();
        if (!version.matches("[0-9]+\\.[0-9]+\\.[0-9]+")) throw new IllegalArgumentException("invalid version");
        String content = Files.readString(Path.of(args[1])).trim();
        if (content.isBlank()) throw new IllegalArgumentException("release notes are empty");
        String marker = "release:" + version;
        try (Connection connection = DriverManager.getConnection(required("RELEASE_DB_URL"), required("RELEASE_DB_USER"), required("RELEASE_DB_PASSWORD"))) {
            try (PreparedStatement query = connection.prepareStatement("SELECT COUNT(*) FROM " + NOTICE_TABLE + " WHERE remark=?")) {
                query.setString(1, marker);
                try (ResultSet result = query.executeQuery()) { result.next(); if (result.getInt(1) > 0) { System.out.println("release notice already exists: " + version); return; } }
            }
            try (PreparedStatement statement = connection.prepareStatement("INSERT INTO " + NOTICE_TABLE + "(notice_id,tenant_id,notice_title,notice_type,notice_content,status,create_dept,create_by,create_time,remark) VALUES(?,'" + DEFAULT_TENANT + "',?,'2',?,'1',103,1,NOW(),?)")) {
                statement.setLong(1, System.currentTimeMillis()); statement.setString(2, "宠物友好指南 v" + version + " 发布");
                statement.setBytes(3, content.getBytes(java.nio.charset.StandardCharsets.UTF_8)); statement.setString(4, marker); statement.executeUpdate();
            }
            System.out.println("published release notice: " + version);
        }
    }
    private static String required(String name) { String value=System.getenv(name); if(value==null||value.isBlank()) throw new IllegalStateException("missing environment: "+name); return value; }
}
