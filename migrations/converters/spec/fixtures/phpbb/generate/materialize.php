<?php
// Materializes a phpBB version's schema (from its migration definitions) into a
// live MySQL or Postgres database using phpBB's own `db_tools`, so the dumped
// DDL is exactly what phpBB would create. Reads a checked-out phpBB tree and the
// target connection from the environment; bootstrap differs across versions
// (the filesystem namespace, the sqlite driver name, and the db_tools factory
// all changed between 3.1 and 3.2), so the right variant is detected at runtime.
//
//   PHPBB_ROOT, TARGET_ENGINE (mysql|postgres),
//   DB_HOST, DB_PORT, DB_USER, DB_PASS, DB_NAME

define('IN_PHPBB', true);
$root = rtrim(getenv('PHPBB_ROOT'), '/') . '/';
$phpEx = 'php';
$table_prefix = 'phpbb_';

require $root . 'vendor/autoload.php';
include $root . 'includes/constants.php';
require $root . 'phpbb/class_loader.php';
(new \phpbb\class_loader('phpbb\\', "{$root}phpbb/", $phpEx))->register();

// `\phpbb\filesystem` (<= 3.1) became `\phpbb\filesystem\filesystem` (>= 3.2).
$filesystem = class_exists('\phpbb\filesystem\filesystem')
    ? new \phpbb\filesystem\filesystem()
    : new \phpbb\filesystem();

$finder = new \phpbb\finder($filesystem, $root);
$classes = $finder->core_path('phpbb/')->directory('/db/migration/data')->get_classes();

// The `sqlite` driver became `sqlite3`, and db_tools moved behind a factory.
$has_factory = class_exists('\phpbb\db\tools\factory');
$sqlite_class = class_exists('\phpbb\db\driver\sqlite3') ? '\phpbb\db\driver\sqlite3' : '\phpbb\db\driver\sqlite';
$sqlite = new $sqlite_class();

$build_tools = static function ($db, $return_statements = false) use ($has_factory) {
    return $has_factory
        ? (new \phpbb\db\tools\factory())->get($db, $return_statements)
        : new \phpbb\db\tools($db, $return_statements);
};

$generator = new \phpbb\db\migration\schema_generator(
    $classes,
    new \phpbb\config\config([]),
    $sqlite,
    $build_tools($sqlite, true),
    $root,
    $phpEx,
    $table_prefix
);
$schema = $generator->get_schema();

$engine = getenv('TARGET_ENGINE');
$db = $engine === 'mysql' ? new \phpbb\db\driver\mysqli() : new \phpbb\db\driver\postgres();
$db->sql_connect(
    getenv('DB_HOST'),
    getenv('DB_USER'),
    getenv('DB_PASS'),
    getenv('DB_NAME'),
    (int) getenv('DB_PORT'),
    false,
    false
);

$tools = $build_tools($db);
$created = 0;
foreach ($schema as $table => $table_data) {
    if (!$tools->sql_table_exists($table)) {
        $tools->sql_create_table($table, $table_data);
        $created++;
    }
}
fwrite(STDERR, "materialized {$created} tables into {$engine}/" . getenv('DB_NAME') . "\n");
