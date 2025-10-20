<?php
$conx = mysqli_connect("localhost", "mrthhzmy_erp2025", "A122%133zzzz", "mrthhzmy_erp2025");

if (!$conx) {
    die("Connection failed: " . mysqli_connect_error());
}

mysqli_set_charset($conx, "utf8");

// Test visits_det table
$query = "SELECT COUNT(*) as count FROM visits_det";
$result = mysqli_query($conx, $query);
$row = mysqli_fetch_assoc($result);
echo "visits_det count: " . $row['count'] . "\n";

// Test visitsx table  
$query = "SELECT COUNT(*) as count FROM visitsx";
$result = mysqli_query($conx, $query);
$row = mysqli_fetch_assoc($result);
echo "visitsx count: " . $row['count'] . "\n";

// Get sample visit IDs
$query = "SELECT id FROM visits_det LIMIT 5";
$result = mysqli_query($conx, $query);
echo "Sample visit IDs:\n";
while ($row = mysqli_fetch_assoc($result)) {
    echo "- " . $row['id'] . "\n";
}
?>
