int pointsForVerifiedKg(double kilograms) => (kilograms * 10).round();
String levelForPoints(int points) => points >= 2500
    ? 'Pahlawan Sirkular'
    : points >= 1000
    ? 'Pejuang Kota Sirkular'
    : points >= 250
    ? 'Sahabat Lingkungan'
    : 'Pemula Sirkular';
double estimatedDiversionKg(Iterable<double> weights) =>
    weights.fold(0, (sum, weight) => sum + weight);
