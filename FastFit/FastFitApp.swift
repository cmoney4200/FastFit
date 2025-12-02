import SwiftUI
import CoreLocation
import Combine
import MapKit
import Foundation

// ---------------------------------------------------------
// MARK: - THEME CONSTANTS (CYBERPUNK)
// ---------------------------------------------------------
//New Version again
struct CyberTheme {
    static let bgDark = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let cardBg = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let neonCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 1.0)
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.25)
    static let neonPurple = Color(red: 0.7, green: 0.0, blue: 1.0)
    static let neonOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let stravaOrange = Color(red: 0.99, green: 0.34, blue: 0.13)
    static let textMain = Color.white
    static let textDim = Color.gray
}

struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat = 8
    func body(content: Content) -> some View {
        content.shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color, radius: CGFloat = 8) -> some View {
        self.modifier(NeonGlow(color: color, radius: radius))
    }
}

// ---------------------------------------------------------
// MARK: - APP ENTRY POINT
// ---------------------------------------------------------

enum AppState {
    case welcomeCube
    case welcomeCowboy
    case dashboard
}

@main
struct FastFitApp: App {
    @State private var appState: AppState = .welcomeCube

    init() {
        UITabBar.appearance().backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
        UITabBar.appearance().barTintColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .bold)]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)]
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState {
                case .welcomeCube:
                    WelcomeView(appState: $appState)
                        .transition(.opacity)
                case .welcomeCowboy:
                    CowboyView(appState: $appState)
                        .transition(.move(edge: .trailing))
                case .dashboard:
                    FastFitDashboard()
                        .transition(.opacity.animation(.easeInOut(duration: 1.0)))
                }
            }
            .animation(.easeInOut, value: appState)
            .preferredColorScheme(.dark)
        }
    }
}

// ---------------------------------------------------------
// MARK: - USER HISTORY & DATABASE
// ---------------------------------------------------------

struct StravaActivity: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let calories: Int
    let duration: String
    let icon: String
}

class UserHistory: ObservableObject {
    static let shared = UserHistory()
    
    struct EatenItem: Identifiable {
        let id = UUID()
        let item: MenuItem
    }
    
    @Published var userName: String = ""
    @Published var eatenItems: [EatenItem] = []
    @Published var steps: Double = 6500
    @Published var strengthMinutes: Double = 0
    @Published var isStravaConnected: Bool = false
    @Published var stravaActivities: [StravaActivity] = []
    
    let baseCalorieGoal = 2200
    let baseProteinGoal = 150
    let carbGoal = 200
    
    func addItem(_ item: MenuItem) { eatenItems.append(EatenItem(item: item)) }
    func removeItem(at offsets: IndexSet) { eatenItems.remove(atOffsets: offsets) }
    
    var totalCaloriesEaten: Int { eatenItems.reduce(0) { $0 + $1.item.cals } }
    var totalProteinEaten: Int { eatenItems.reduce(0) { $0 + parseMacro($1.item.protein) } }
    var totalCarbsEaten: Int { eatenItems.reduce(0) { $0 + parseMacro($1.item.carbs) } }
    var totalFatEaten: Int { eatenItems.reduce(0) { $0 + parseMacro($1.item.fat) } }
    
    var activeBurnFromSteps: Int { Int(floor(steps * 0.04)) }
    var activeBurnFromLifting: Int { Int(floor(strengthMinutes * 5.0)) }
    
    var activeBurnFromStrava: Int {
        guard isStravaConnected else { return 0 }
        return stravaActivities.reduce(0) { $0 + $1.calories }
    }
    
    var totalDailyCalorieGoal: Int { baseCalorieGoal + activeBurnFromSteps + activeBurnFromLifting + activeBurnFromStrava }
    
    var isStrengthTrainingDay: Bool {
        return strengthMinutes > 20
    }
    
    var totalDailyProteinGoal: Int {
        return isStrengthTrainingDay ? baseProteinGoal + 50 : baseProteinGoal
    }
    
    private func parseMacro(_ value: String) -> Int {
        return Int(value.replacingOccurrences(of: "g", with: "")) ?? 0
    }
    
    func connectStrava() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isStravaConnected = true
            self.stravaActivities = [
                StravaActivity(name: "Morning Run", type: "Run", calories: 450, duration: "45 min", icon: "figure.run"),
                StravaActivity(name: "Lunch Ride", type: "Ride", calories: 320, duration: "30 min", icon: "bicycle")
            ]
        }
    }
    
    func disconnectStrava() {
        isStravaConnected = false
        stravaActivities = []
    }
}

class NutritionDatabase: ObservableObject {
    static let shared = NutritionDatabase()
    @Published var allItems: [MenuItem] = []
    @Published var isLoading = true
    private var supportedRestaurantNames: Set<String> = []
    
    private let fallbackData = """
    restaurant,item,calories,cal_fat,total_fat,sat_fat,trans_fat,cholesterol,sodium,total_carb,fiber,sugar,protein,vit_a,vit_c,calcium,salad
    Mcdonalds,Artisan Grilled Chicken Sandwich,380,0,7,0,0,0,0,44,0,0,37,0,0,0,Other
    Mcdonalds,Grilled Chicken Salad,350,0,15,0,0,0,0,12,0,0,38,0,0,0,Other
    Taco Bell,Power Menu Bowl - Chicken,470,0,19,0,0,0,0,50,0,0,26,0,0,0,Other
    Subway,Turkey Breast (6 inch),280,0,3.5,0,0,0,0,46,0,0,18,0,0,0,Other
    Chick-fil-A,Grilled Chicken Sandwich,320,0,6,0,0,0,0,41,0,0,28,0,0,0,Other
    """
    
    init() { loadDataBackground() }
    
    func loadDataBackground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var csvString = ""
            if let filepath = Bundle.main.path(forResource: "fastfood", ofType: "csv") {
                do { csvString = try String(contentsOfFile: filepath) } catch { csvString = self.fallbackData }
            } else { csvString = self.fallbackData }
            let parsedItems = self.parseCSV(data: csvString)
            DispatchQueue.main.async { self.allItems = parsedItems; self.isLoading = false }
        }
    }
    
    private func parseCSV(data: String) -> [MenuItem] {
        var rows = data.components(separatedBy: "\n")
        if let first = rows.first, first.contains("restaurant") { rows.removeFirst() }
        var items: [MenuItem] = []
        var foundNames: Set<String> = []
        for row in rows {
            let columns = row.components(separatedBy: ",")
            if columns.count >= 13 {
                let restaurant = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                foundNames.insert(normalize(restaurant))
                let itemName = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let cals = Int(columns[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                let fat = (columns[4].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : columns[4].trimmingCharacters(in: .whitespacesAndNewlines)) + "g"
                let carbs = (columns[9].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0" : columns[9].trimmingCharacters(in: .whitespacesAndNewlines)) + "g"
                let proteinRaw = columns[12].trimmingCharacters(in: .whitespacesAndNewlines)
                let protein = (proteinRaw.isEmpty ? "0" : proteinRaw) + "g"
                
                var tags: [String] = []
                let pVal = Double(proteinRaw) ?? 0
                let cVal = Double(columns[9].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                if pVal > 25 { tags.append("High Protein") }
                if cVal < 35 { tags.append("Low Carb") }
                if cals < 450 { tags.append("Low Cal") }
                
                var emoji = "🍽️"
                let lowerName = itemName.lowercased()
                if lowerName.contains("salad") { emoji = "🥗" }
                else if lowerName.contains("chicken") { emoji = "🍗" }
                else if lowerName.contains("burger") { emoji = "🍔" }
                else if lowerName.contains("taco") { emoji = "🌮" }
                
                let newItem = MenuItem(id: UUID().hashValue, restaurantName: restaurant, name: itemName, cals: cals, protein: protein, carbs: carbs, fat: fat, tags: tags, image: emoji)
                items.append(newItem)
            }
        }
        self.supportedRestaurantNames = foundNames
        return items
    }
    
    private func normalize(_ text: String) -> String {
        return text.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
    }
    
    func isRestaurantSupported(_ name: String) -> Bool {
        let target = normalize(name)
        return supportedRestaurantNames.contains { dbName in target.contains(dbName) || dbName.contains(target) }
    }
    
    func getRecommendations(nearbyRestaurants: [String], calorieBudget: Int, prioritizeProtein: Bool) -> [MenuItem] {
        let normalizedNearby = nearbyRestaurants.map { normalize($0) }
        let filtered = allItems.filter { item in
            let itemRest = normalize(item.restaurantName)
            let isMatch = normalizedNearby.contains { mapName in itemRest.contains(mapName) || mapName.contains(itemRest) }
            return isMatch && item.cals <= calorieBudget && item.cals > 0
        }
        
        if prioritizeProtein {
            return filtered.sorted { $0.proteinVal > $1.proteinVal }
        } else {
            return filtered.sorted { $0.proteinVal > $1.proteinVal }
        }
    }
    
    func getItemsForRestaurant(name: String, calorieBudget: Int) -> [MenuItem] {
        let targetName = normalize(name)
        return allItems.filter { item in
            let itemRest = normalize(item.restaurantName)
            let isMatch = itemRest.contains(targetName) || targetName.contains(itemRest)
            return isMatch && item.cals <= calorieBudget && item.cals > 0
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationName: String = "SCANNING..."
    @Published var nearbyPlaces: [Restaurant] = []
    @Published var statusMessage: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus?
    
    override init() {
        super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func refreshLocation() {
        if let loc = location { fetchNearbyRestaurants(location: loc) } else { manager.requestLocation() }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.startUpdatingLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if self.location == nil || self.location!.distance(from: location) > 200 {
            self.location = location; updateLocationName(location); fetchNearbyRestaurants(location: location)
        }
    }
    private func updateLocationName(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in if let place = placemarks?.first { self.locationName = (place.locality ?? "UNKNOWN").uppercased() } }
    }
    func fetchNearbyRestaurants(location: CLLocation) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Fast Food"; request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 3000, longitudinalMeters: 3000)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let items = response?.mapItems else { return }
            DispatchQueue.main.async {
                let validItems = items.filter { NutritionDatabase.shared.isRestaurantSupported($0.name ?? "") }
                self.statusMessage = validItems.isEmpty ? "NO DATA FOUND IN SECTOR" : ""
                self.nearbyPlaces = validItems.map { item in
                    let dist = item.placemark.location?.distance(from: location) ?? 0
                    return Restaurant(id: item.hash, name: item.name ?? "UNKNOWN", distance: String(format: "%.1f mi", dist / 1609.34), type: "Food Node", color: .orange)
                }
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

struct Restaurant: Identifiable { let id: Int; let name: String; let distance: String; let type: String; let color: Color }
struct MenuItem: Identifiable, Equatable {
    let id: Int; let restaurantName: String; let name: String; let cals: Int; let protein: String; let carbs: String; let fat: String; let tags: [String]; let image: String
    var proteinVal: Double { Double(protein.replacingOccurrences(of: "g", with: "")) ?? 0 }
    var carbsVal: Double { Double(carbs.replacingOccurrences(of: "g", with: "")) ?? 0 }
}
enum SortOption: String, CaseIterable { case caloriesLow = "LO-CAL"; case proteinHigh = "HI-PRO"; case carbsLow = "LO-CARB" }

// ---------------------------------------------------------
// MARK: - DASHBOARD VIEW
// ---------------------------------------------------------

struct FastFitDashboard: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var nutritionDB = NutritionDatabase.shared
    @StateObject private var userHistory = UserHistory.shared
    @State private var selectedTab = "home"
    @State private var selectedItem: MenuItem? = nil
    
    // Tracks if onboarding has been seen. We toggle this to false to SHOW the overlay.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    var remainingBudget: Int { max(0, userHistory.totalDailyCalorieGoal - userHistory.totalCaloriesEaten) }
    var recommendations: [MenuItem] {
        nutritionDB.getRecommendations(
            nearbyRestaurants: locationManager.nearbyPlaces.map { $0.name },
            calorieBudget: remainingBudget,
            prioritizeProtein: userHistory.isStrengthTrainingDay
        )
    }
    
    var body: some View {
        ZStack {
            CyberTheme.bgDark.ignoresSafeArea()
            if selectedItem != nil {
                if let item = selectedItem {
                    ItemDetailView(item: item, selectedItem: $selectedItem, userHistory: userHistory).transition(.move(edge: .trailing)).zIndex(2)
                }
            } else {
                TabView(selection: $selectedTab) {
                    HomeView(userHistory: userHistory, remainingBudget: remainingBudget, recommendations: recommendations, selectedItem: $selectedItem, locationManager: locationManager, isLoadingDB: nutritionDB.isLoading)
                        .tag("home").tabItem { Label("HOME", systemImage: "house.fill") }
                    SearchView(locationManager: locationManager, calorieBudget: remainingBudget, selectedItem: $selectedItem, userHistory: userHistory)
                        .tag("search").tabItem { Label("SCAN", systemImage: "waveform.circle.fill") }
                    // PASS BINDING FOR HELP RESET
                    ProfileView(userHistory: userHistory, hasSeenOnboarding: $hasSeenOnboarding)
                        .tag("profile").tabItem { Label("DATA", systemImage: "cpu") }
                }.accentColor(CyberTheme.neonCyan)
            }
            
            // HELP OVERLAY
            if !hasSeenOnboarding {
                HelpOverlayView(isPresented: Binding(
                    get: { !hasSeenOnboarding },
                    set: { hasSeenOnboarding = !$0 }
                ))
                .zIndex(10)
            }
        }
    }
}

// NEW: Help Overlay Component
struct HelpOverlayView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Pointer 1: Sliders
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down")
                        .font(.title).foregroundColor(CyberTheme.neonPink)
                    Text("ADJUST ACTIVITY LEVELS\nTO INCREASE CALORIE BUDGET")
                        .font(.system(.headline, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                }
                .padding(.top, 100)
                
                Spacer()
                
                // Pointer 2: Scan Button
                VStack(spacing: 10) {
                    Text("SCAN FOR NEARBY\nFAST FOOD OPTIONS")
                        .font(.system(.headline, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    Image(systemName: "arrow.down")
                        .font(.title).foregroundColor(CyberTheme.neonCyan)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isPresented = false // Dismiss and save to AppStorage
                    }
                }) {
                    Text("GOT IT, LET'S EAT")
                        .font(.system(.headline, design: .monospaced))
                        .bold()
                        .foregroundColor(.black)
                        .padding()
                        .background(CyberTheme.neonGreen)
                        .cornerRadius(8)
                        .neonGlow(color: CyberTheme.neonGreen)
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
        .onTapGesture {
            withAnimation {
                isPresented = false
            }
        }
    }
}


struct HomeView: View {
    @ObservedObject var userHistory: UserHistory
    let remainingBudget: Int
    let recommendations: [MenuItem]
    @Binding var selectedItem: MenuItem?
    @ObservedObject var locationManager: LocationManager
    var isLoadingDB: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("USER: \(userHistory.userName.isEmpty ? "UNKNOWN" : userHistory.userName)").font(.system(.title3, design: .monospaced)).bold().foregroundColor(CyberTheme.neonCyan)
                            Text("SYSTEM READY").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                        }
                        Spacer()
                        Image("AppLogo").resizable().aspectRatio(contentMode: .fit).frame(width: 50, height: 50).background(Color.black).clipShape(Circle()).overlay(Circle().stroke(CyberTheme.neonCyan, lineWidth: 2)).neonGlow(color: CyberTheme.neonCyan)
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(CyberTheme.cardBg).overlay(RoundedRectangle(cornerRadius: 16).stroke(CyberTheme.neonPink, lineWidth: 1)).neonGlow(color: CyberTheme.neonPink.opacity(0.3))
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.text.square.fill").foregroundColor(CyberTheme.neonGreen)
                                    Text("BIO-METRICS").font(.system(.caption, design: .monospaced)).bold().foregroundColor(CyberTheme.neonGreen)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("ENERGY RESERVE").font(.system(.caption2, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                                    Text("\(remainingBudget) KCAL").font(.system(.title2, design: .monospaced)).bold().foregroundColor(CyberTheme.neonPink)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("\(Int(userHistory.steps))").font(.system(size: 36, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                Text("STEPS_DETECTED (+\(userHistory.activeBurnFromSteps) KCAL)").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                            }
                            Slider(value: $userHistory.steps, in: 0...20000).accentColor(CyberTheme.neonCyan)
                            
                            Divider().background(CyberTheme.textDim)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "dumbbell.fill").foregroundColor(CyberTheme.neonPurple)
                                    Text("STRENGTH TRAINING").font(.system(.caption, design: .monospaced)).bold().foregroundColor(CyberTheme.neonPurple)
                                    Spacer()
                                    if userHistory.isStrengthTrainingDay {
                                        Text("HI-PRO MODE ACTIVE").font(.system(size: 8, design: .monospaced)).foregroundColor(CyberTheme.neonGreen)
                                    }
                                }
                                Text("\(Int(userHistory.strengthMinutes)) MINS").font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                Text("LIFTING DURATION (+\(userHistory.activeBurnFromLifting) KCAL)").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                            }
                            Slider(value: $userHistory.strengthMinutes, in: 0...120).accentColor(CyberTheme.neonPurple)
                            
                            if userHistory.isStravaConnected {
                                Divider().background(CyberTheme.textDim)
                                HStack {
                                    Image(systemName: "figure.run").foregroundColor(CyberTheme.stravaOrange)
                                    Text("STRAVA_SYNC: ACTIVE").font(.system(.caption, design: .monospaced)).bold().foregroundColor(CyberTheme.stravaOrange)
                                    Spacer()
                                    Text("+\(userHistory.activeBurnFromStrava) KCAL").font(.system(.caption, design: .monospaced)).bold().foregroundColor(.white)
                                }
                            }
                        }
                        .padding(20)
                    }
                    HStack {
                        Text(userHistory.isStrengthTrainingDay ? "PROTEIN TARGETS" : "TARGET_ACQUISITION").font(.system(.headline, design: .monospaced)).foregroundColor(.white)
                        Spacer()
                        Button(action: { locationManager.refreshLocation() }) {
                            HStack(spacing: 4) { Image(systemName: "antenna.radiowaves.left.and.right"); Text(locationManager.location != nil ? "REFRESH" : "SCAN") }
                                .font(.system(.caption, design: .monospaced)).bold().foregroundColor(CyberTheme.bgDark).padding(6).background(CyberTheme.neonCyan).cornerRadius(4)
                        }
                    }
                    if isLoadingDB {
                        Text("LOADING_DATABASE...").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.neonCyan)
                    } else if recommendations.isEmpty {
                        Text("NO_VIABLE_TARGETS").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim).frame(maxWidth: .infinity).padding(32).background(CyberTheme.cardBg).cornerRadius(12)
                    } else {
                        ForEach(recommendations.prefix(10)) { item in
                            ItemRow(item: item, action: { selectedItem = item })
                        }
                    }
                }
                .padding().background(CyberTheme.bgDark)
            }
            .navigationBarHidden(true).background(CyberTheme.bgDark)
        }
    }
}

struct ItemRow: View {
    let item: MenuItem
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(item.image).font(.system(size: 32)).frame(width: 60, height: 60).background(Color.black).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(CyberTheme.textDim.opacity(0.5), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name.uppercased()).font(.system(.subheadline, design: .monospaced)).bold().foregroundColor(.white).lineLimit(1)
                    Text(item.restaurantName.uppercased()).font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                    HStack(spacing: 8) {
                        Text("\(item.cals) CAL").modifier(CyberTag(color: CyberTheme.neonPink))
                        Text(item.protein).modifier(CyberTag(color: CyberTheme.neonCyan))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(CyberTheme.neonCyan)
            }
            .padding(12).background(CyberTheme.cardBg).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(CyberTheme.neonCyan.opacity(0.3), lineWidth: 1))
        }
    }
}

struct CyberTag: ViewModifier {
    var color: Color
    func body(content: Content) -> some View {
        content.font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(color).padding(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1))
    }
}

struct SearchView: View {
    @State private var searchText = ""
    @ObservedObject var locationManager: LocationManager
    var calorieBudget: Int
    @Binding var selectedItem: MenuItem?
    @ObservedObject var userHistory: UserHistory
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("SECTOR_SCAN").font(.system(.largeTitle, design: .monospaced)).bold().foregroundColor(CyberTheme.neonCyan)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(CyberTheme.textDim)
                        TextField("QUERY...", text: $searchText).foregroundColor(.white).accentColor(CyberTheme.neonCyan)
                    }
                    .padding().background(CyberTheme.cardBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(CyberTheme.neonCyan.opacity(0.5), lineWidth: 1))
                    if locationManager.nearbyPlaces.isEmpty {
                        Text(locationManager.statusMessage.isEmpty ? "SCANNING_GRID..." : locationManager.statusMessage).font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                    }
                    ForEach(locationManager.nearbyPlaces) { place in
                        NavigationLink(destination: RestaurantMenuView(restaurant: place, calorieBudget: calorieBudget, selectedItem: $selectedItem, userHistory: userHistory)) {
                            HStack {
                                Text(String(place.name.prefix(1))).font(.title3).bold().frame(width: 40, height: 40).background(CyberTheme.neonCyan.opacity(0.2)).foregroundColor(CyberTheme.neonCyan).clipShape(Circle())
                                VStack(alignment: .leading) {
                                    Text(place.name.uppercased()).bold().font(.system(.body, design: .monospaced)).foregroundColor(.white)
                                    Text("\(place.type) • \(place.distance)").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(CyberTheme.textDim)
                            }
                            .padding().background(CyberTheme.cardBg).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                    }
                }
                .padding().background(CyberTheme.bgDark)
            }
            .navigationBarHidden(true).background(CyberTheme.bgDark)
        }
    }
}

struct RestaurantMenuView: View {
    let restaurant: Restaurant
    let calorieBudget: Int
    @Binding var selectedItem: MenuItem?
    @ObservedObject var userHistory: UserHistory
    @State private var selectedFilters: Set<SortOption> = []
    var items: [MenuItem] {
        let raw = NutritionDatabase.shared.getItemsForRestaurant(name: restaurant.name, calorieBudget: calorieBudget)
        if selectedFilters.isEmpty { return raw.sorted { $0.cals < $1.cals } }
        return raw.sorted { i1, i2 in
            var s1 = 0.0, s2 = 0.0
            if selectedFilters.contains(.caloriesLow) { s1 += (1000.0 - Double(i1.cals)); s2 += (1000.0 - Double(i2.cals)) }
            if selectedFilters.contains(.proteinHigh) { s1 += (i1.proteinVal * 10); s2 += (i2.proteinVal * 10) }
            if selectedFilters.contains(.carbsLow) { s1 += (100.0 - i1.carbsVal) * 5; s2 += (100.0 - i2.carbsVal) * 5 }
            return s1 > s2
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(restaurant.name.uppercased()).font(.system(.title2, design: .monospaced)).bold().foregroundColor(.white).padding(.top)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(SortOption.allCases, id: \.self) { opt in
                            Button(action: { if selectedFilters.contains(opt) { selectedFilters.remove(opt) } else { selectedFilters.insert(opt) } }) {
                                Text(opt.rawValue).font(.system(.caption, design: .monospaced)).bold().padding(.vertical, 8).padding(.horizontal, 16).background(selectedFilters.contains(opt) ? CyberTheme.neonCyan : Color.clear).foregroundColor(selectedFilters.contains(opt) ? .black : CyberTheme.neonCyan).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke(CyberTheme.neonCyan, lineWidth: 1))
                            }
                        }
                    }
                }
                if items.isEmpty {
                    Text("NO_COMPATIBLE_ITEMS").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                } else {
                    ForEach(items) { item in
                        HStack {
                            Button(action: { selectedItem = item }) {
                                HStack {
                                    Text(item.image).font(.largeTitle)
                                    VStack(alignment: .leading) {
                                        Text(item.name).font(.system(.subheadline, design: .monospaced)).bold().foregroundColor(.white).lineLimit(1)
                                        HStack {
                                            Text("\(item.cals) CAL").font(.caption).foregroundColor(CyberTheme.neonPink)
                                            Text(item.protein).font(.caption).foregroundColor(CyberTheme.neonGreen)
                                        }
                                    }
                                }
                            }
                            Spacer()
                            Button(action: { userHistory.addItem(item) }) { Image(systemName: "plus.square.fill").font(.title2).foregroundColor(CyberTheme.neonCyan) }
                        }
                        .padding().background(CyberTheme.cardBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
            }
            .padding().background(CyberTheme.bgDark)
        }
        .background(CyberTheme.bgDark)
    }
}

struct ProfileView: View {
    @ObservedObject var userHistory: UserHistory
    @Binding var hasSeenOnboarding: Bool // BINDING to reset state
    @State private var isConnectingStrava = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Image("AppLogo").resizable().frame(width: 80, height: 80).clipShape(Circle()).overlay(Circle().stroke(CyberTheme.neonPurple, lineWidth: 2)).neonGlow(color: CyberTheme.neonPurple)
                        VStack(alignment: .leading) {
                            Text("ID: \(userHistory.userName.isEmpty ? "UNKNOWN" : userHistory.userName)").font(.system(.title2, design: .monospaced)).bold().foregroundColor(.white)
                            Text("STATUS: ONLINE").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.neonGreen)
                        }
                    }
                    
                    // RESET HELP BUTTON
                    Button(action: {
                        hasSeenOnboarding = false
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("RESET HELP TIPS")
                        }
                        .font(.system(.caption, design: .monospaced)).bold()
                        .foregroundColor(CyberTheme.neonCyan)
                        .padding(8)
                        .background(CyberTheme.cardBg)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CyberTheme.neonCyan, lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("EXTERNAL_LINKS").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                        if userHistory.isStravaConnected {
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "link").foregroundColor(CyberTheme.stravaOrange)
                                    Text("STRAVA CONNECTED").font(.system(.body, design: .monospaced)).bold().foregroundColor(CyberTheme.stravaOrange)
                                    Spacer()
                                    Button("DISCONNECT") { userHistory.disconnectStrava() }.font(.caption).foregroundColor(.gray)
                                }
                                Divider().background(Color.white.opacity(0.2))
                                ForEach(userHistory.stravaActivities) { activity in
                                    HStack {
                                        Image(systemName: activity.icon).foregroundColor(.white)
                                        VStack(alignment: .leading) {
                                            Text(activity.name).font(.system(.caption, design: .monospaced)).bold().foregroundColor(.white)
                                            Text("\(activity.type) • \(activity.duration)").font(.caption).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("+\(activity.calories)").font(.system(.body, design: .monospaced)).bold().foregroundColor(CyberTheme.neonGreen)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding().background(CyberTheme.cardBg).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(CyberTheme.stravaOrange, lineWidth: 1))
                        } else {
                            Button(action: {
                                isConnectingStrava = true; userHistory.connectStrava()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isConnectingStrava = false }
                            }) {
                                HStack {
                                    if isConnectingStrava { ProgressView().padding(.trailing, 5); Text("ESTABLISHING UPLINK...") }
                                    else { Image(systemName: "arrow.triangle.2.circlepath"); Text("CONNECT STRAVA") }
                                }
                                .font(.system(.body, design: .monospaced)).bold().foregroundColor(.white).frame(maxWidth: .infinity).padding().background(CyberTheme.stravaOrange).cornerRadius(12).neonGlow(color: CyberTheme.stravaOrange)
                            }
                            .disabled(isConnectingStrava)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DAILY_METRICS").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                        HStack {
                            ReportCard(title: "CALORIES", current: userHistory.totalCaloriesEaten, target: userHistory.totalDailyCalorieGoal, color: CyberTheme.neonPink)
                            ReportCard(title: "PROTEIN", current: userHistory.totalProteinEaten, target: userHistory.totalDailyProteinGoal, color: CyberTheme.neonCyan)
                        }
                        HStack {
                            ReportCard(title: "CARBS", current: userHistory.totalCarbsEaten, target: userHistory.carbGoal, color: CyberTheme.neonPurple)
                            ReportCard(title: "FAT", current: userHistory.totalFatEaten, target: 70, color: .orange)
                        }
                    }
                    Text("CONSUMPTION_LOG").font(.system(.headline, design: .monospaced)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
                    if userHistory.eatenItems.isEmpty {
                        Text("LOG_EMPTY").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim).padding().frame(maxWidth: .infinity).background(CyberTheme.cardBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5])))
                    } else {
                        ForEach(userHistory.eatenItems) { eatenItem in
                            HStack {
                                Text(eatenItem.item.image)
                                Text(eatenItem.item.name).font(.system(.caption, design: .monospaced)).foregroundColor(.white).lineLimit(1)
                                Spacer()
                                Text("\(eatenItem.item.cals)").font(.system(.caption, design: .monospaced)).bold().foregroundColor(CyberTheme.neonPink)
                                Button(action: {
                                    if let index = userHistory.eatenItems.firstIndex(where: { $0.id == eatenItem.id }) { userHistory.removeItem(at: IndexSet(integer: index)) }
                                }) { Image(systemName: "trash").foregroundColor(.red).padding(8) }
                            }
                            .padding().background(CyberTheme.cardBg).cornerRadius(8)
                        }
                    }
                }
                .padding().background(CyberTheme.bgDark)
            }
            .navigationBarHidden(true).background(CyberTheme.bgDark)
        }
    }
}

struct ReportCard: View {
    let title: String; let current: Int; let target: Int; let color: Color
    var progress: Double { min(Double(current) / Double(target), 1.0) }
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.system(size: 10, design: .monospaced)).bold().foregroundColor(color)
            Text("\(current) / \(target)").font(.system(.title3, design: .monospaced)).bold().foregroundColor(.white)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.black).frame(height: 4)
                Rectangle().fill(color).frame(width: 150 * progress, height: 4).neonGlow(color: color, radius: 4)
            }
        }
        .padding().background(CyberTheme.cardBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 1))
    }
}

// ---------------------------------------------------------
// MARK: - COWBOY VIEW (SECOND WELCOME - WITH NAME INPUT)
// ---------------------------------------------------------

struct CowboyView: View {
    @Binding var appState: AppState
    @StateObject private var userHistory = UserHistory.shared
    @State private var nameInput: String = ""
    
    var body: some View {
        ZStack {
            CyberTheme.bgDark.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    Text("HOWDY PARTNER, WELCOME TO FASTFIT.").font(.system(.body, design: .monospaced)).bold().foregroundColor(CyberTheme.neonCyan)
                    Text("The app where you can track your daily fixins and figure out what you need to wrangle next.").font(.system(.caption, design: .monospaced)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                }
                .padding().background(
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 12).fill(CyberTheme.cardBg).overlay(RoundedRectangle(cornerRadius: 12).stroke(CyberTheme.neonCyan, lineWidth: 2))
                        Path { path in path.move(to: CGPoint(x: 40, y: 0)); path.addLine(to: CGPoint(x: 50, y: 15)); path.addLine(to: CGPoint(x: 60, y: 0)) }.fill(CyberTheme.cardBg)
                            .overlay(Path { path in path.move(to: CGPoint(x: 40, y: 0)); path.addLine(to: CGPoint(x: 50, y: 15)); path.addLine(to: CGPoint(x: 60, y: 0)) }.stroke(CyberTheme.neonCyan, lineWidth: 2).mask(Rectangle().padding(.top, 2)))
                            .frame(height: 15).offset(y: 14)
                    }
                ).padding(.horizontal).padding(.bottom, 20)
                Image("CowBoy").resizable().aspectRatio(contentMode: .fit).frame(height: 200).shadow(color: CyberTheme.neonOrange.opacity(0.5), radius: 10)
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("ENTER ID HANDLE:").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.neonOrange).padding(.leading, 4)
                    TextField("TYPE NAME HERE...", text: $nameInput).font(.system(.body, design: .monospaced)).foregroundColor(.white).padding().background(CyberTheme.cardBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(CyberTheme.neonOrange, lineWidth: 1))
                }
                .padding(.horizontal, 40)
                Button(action: { userHistory.userName = nameInput.isEmpty ? "PARTNER" : nameInput.uppercased(); withAnimation { appState = .dashboard } }) {
                    VStack(spacing: 8) { Text("LET'S RIDE").font(.system(.headline, design: .monospaced)).bold().foregroundColor(CyberTheme.bgDark); Image(systemName: "arrow.right").foregroundColor(CyberTheme.bgDark) }
                        .frame(maxWidth: .infinity).padding().background(CyberTheme.neonOrange).cornerRadius(4).neonGlow(color: CyberTheme.neonOrange)
                }
                .padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
    }
}

// ---------------------------------------------------------
// MARK: - WELCOME VIEW (CUBE)
// ---------------------------------------------------------

struct WelcomeView: View {
    @Binding var appState: AppState
    @State private var isProceeding = false
    
    var body: some View {
        ZStack {
            CyberTheme.bgDark.ignoresSafeArea()
            VStack(spacing: 40) {
                Spacer()
                VStack(spacing: 8) {
                    Text("WELCOME TO").font(.system(.title3, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                    Text("FASTFIT").font(.system(size: 60, weight: .black, design: .monospaced)).foregroundColor(.white).neonGlow(color: CyberTheme.neonCyan)
                }
                SpinningCube(isExcited: isProceeding).frame(height: 300)
                Spacer()
                Button(action: { withAnimation { isProceeding = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { appState = .welcomeCowboy } } }) {
                    VStack(spacing: 8) { Text("TAP TO PROCEED").font(.system(.headline, design: .monospaced)).bold().foregroundColor(CyberTheme.bgDark); Image(systemName: "chevron.right").foregroundColor(CyberTheme.bgDark) }
                        .frame(maxWidth: .infinity).padding().background(CyberTheme.neonGreen).cornerRadius(4).neonGlow(color: CyberTheme.neonGreen)
                }
                .padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
    }
}

// ---------------------------------------------------------
// MARK: - EXPLOSION EFFECT
// ---------------------------------------------------------

struct ExplosionView: View {
    struct Particle: Identifiable { let id = UUID(); var x: CGFloat = 0; var y: CGFloat = 0; let angle: Double; let speed: CGFloat; let scale: CGFloat; let color: Color; var opacity: Double = 1.0 }
    @State private var particles: [Particle] = []
    @State private var cloudOpacity: Double = 1.0
    @State private var scale: CGFloat = 0.1
    
    var body: some View {
        ZStack {
            Circle().fill(Color.white).scaleEffect(scale * 1.5).opacity(cloudOpacity * 0.5).blur(radius: 20)
            ForEach(particles) { p in Circle().fill(p.color).frame(width: 20 * p.scale, height: 20 * p.scale).position(x: 150 + p.x, y: 250 + p.y).opacity(p.opacity).blur(radius: 5) }
        }
        .frame(width: 300, height: 400)
        .onAppear { generateMushroomCloud() }
    }
    
    func generateMushroomCloud() {
        var newParticles: [Particle] = []
        for _ in 0..<40 { newParticles.append(Particle(angle: Double.random(in: -.pi/2 - 0.2 ... -.pi/2 + 0.2), speed: CGFloat.random(in: 50...200), scale: CGFloat.random(in: 0.5...1.5), color: [.orange, .red, Color(white: 0.3)].randomElement()!)) }
        for _ in 0..<60 { newParticles.append(Particle(angle: Double.random(in: -.pi...0), speed: CGFloat.random(in: 100...180), scale: CGFloat.random(in: 1.0...2.5), color: [CyberTheme.neonPink, .orange, .white].randomElement()!)) }
        for _ in 0..<30 { newParticles.append(Particle(angle: Double.random(in: -.pi ... 0), speed: CGFloat.random(in: 20...80), scale: CGFloat.random(in: 0.3...0.8), color: [CyberTheme.neonCyan, .gray].randomElement()!)) }
        particles = newParticles
        withAnimation(.easeOut(duration: 0.2)) { scale = 1.2 }
        withAnimation(.easeOut(duration: 1.2)) {
            scale = 1.0; cloudOpacity = 0
            for i in 0..<particles.count {
                if i >= 40 && i < 100 { particles[i].y -= 200; particles[i].x += cos(particles[i].angle) * particles[i].speed; particles[i].y += sin(particles[i].angle) * particles[i].speed * 0.5 }
                else if i < 40 { particles[i].y -= CGFloat.random(in: 100...250); particles[i].x += CGFloat.random(in: -20...20) }
                else { particles[i].x += cos(particles[i].angle) * particles[i].speed * 2 }
                particles[i].opacity = 0
            }
        }
    }
}

// ---------------------------------------------------------
// MARK: - SPINNING CUBE
// ---------------------------------------------------------

struct SpinningCube: View {
    var isExcited: Bool
    @State private var angle: Double = 0
    struct Point3D { var x: Double; var y: Double; var z: Double }
    
    let cubeVertices: [Point3D] = [Point3D(x: -1, y: -1, z: -1), Point3D(x: 1, y: -1, z: -1), Point3D(x: 1, y: 1, z: -1), Point3D(x: -1, y: 1, z: -1), Point3D(x: -1, y: -1, z: 1), Point3D(x: 1, y: -1, z: 1), Point3D(x: 1, y: 1, z: 1), Point3D(x: -1, y: 1, z: 1)]
    let cubeEdges: [(Int, Int)] = [(0,1), (1,2), (2,3), (3,0), (4,5), (5,6), (6,7), (7,4), (0,4), (1,5), (2,6), (3,7)]
    let faceCenter = Point3D(x: 0, y: 0, z: 0)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let currentAngle = time * 1.0
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let scale = min(size.width, size.height) / 3.5
                
                for edge in cubeEdges {
                    let start = project(cubeVertices[edge.0], angle: currentAngle, scale: scale, center: center)
                    let end = project(cubeVertices[edge.1], angle: currentAngle, scale: scale, center: center)
                    var path = Path(); path.move(to: start); path.addLine(to: end)
                    context.stroke(path, with: .color(CyberTheme.neonPink.opacity(0.5)), style: StrokeStyle(lineWidth: 1, lineCap: .butt, dash: [4, 4]))
                }
                for vertex in cubeVertices {
                    let point = project(vertex, angle: currentAngle, scale: scale, center: center)
                    context.draw(Text("+").font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.neonPink), at: point)
                }
                let facePoint = project(faceCenter, angle: currentAngle, scale: scale, center: center)
                let circleSize: CGFloat = 100
                var circlePath = Path()
                circlePath.addEllipse(in: CGRect(x: facePoint.x - circleSize/2, y: facePoint.y - circleSize/2, width: circleSize, height: circleSize))
                context.stroke(circlePath, with: .color(CyberTheme.neonCyan), style: StrokeStyle(lineWidth: 2))
                
                if isExcited {
                    context.draw(Text("O").font(.system(size: 40, weight: .black, design: .monospaced)).foregroundColor(CyberTheme.neonGreen), at: CGPoint(x: facePoint.x, y: facePoint.y + 5))
                    context.draw(Text("^").font(.system(.title, design: .monospaced)).bold().foregroundColor(CyberTheme.neonGreen), at: CGPoint(x: facePoint.x - 20, y: facePoint.y - 15))
                    context.draw(Text("^").font(.system(.title, design: .monospaced)).bold().foregroundColor(CyberTheme.neonGreen), at: CGPoint(x: facePoint.x + 20, y: facePoint.y - 15))
                } else {
                    context.draw(Text("^‿^").font(.system(.largeTitle, design: .monospaced)).bold().foregroundColor(CyberTheme.neonGreen), at: facePoint)
                }
            }
        }
    }
    func project(_ p: Point3D, angle: Double, scale: Double, center: CGPoint) -> CGPoint {
        let x1 = p.x * cos(angle) - p.z * sin(angle); let z1 = p.x * sin(angle) + p.z * cos(angle); let y2 = p.y * cos(angle * 0.2) - z1 * sin(angle * 0.2)
        return CGPoint(x: center.x + x1 * scale, y: center.y + y2 * scale)
    }
}

// ---------------------------------------------------------
// MARK: - ITEM DETAIL (WITH EXPLOSION EFFECT)
// ---------------------------------------------------------

struct ItemDetailView: View {
    let item: MenuItem
    @Binding var selectedItem: MenuItem?
    @ObservedObject var userHistory: UserHistory
    @State private var isExploding = false
    var body: some View {
        ZStack {
            CyberTheme.bgDark.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button(action: { withAnimation { selectedItem = nil } }) { Image(systemName: "arrow.left").foregroundColor(CyberTheme.neonCyan).font(.title2) }
                    Spacer()
                    Text("ITEM_ANALYSIS").font(.system(.headline, design: .monospaced)).foregroundColor(CyberTheme.neonCyan)
                    Spacer()
                }
                .padding()
                VStack(spacing: 16) {
                    ZStack {
                        if !isExploding { Text(item.image).font(.system(size: 100)).shadow(color: CyberTheme.neonPink, radius: 20).transition(.scale) }
                        else { ExplosionView() }
                    }
                    .frame(height: 120)
                    Text(item.name.uppercased()).font(.system(.title2, design: .monospaced)).bold().foregroundColor(.white).multilineTextAlignment(.center)
                    Text(item.restaurantName.uppercased()).font(.system(.caption, design: .monospaced)).foregroundColor(CyberTheme.textDim)
                    HStack(spacing: 20) {
                        MacroData(label: "PRO", value: item.protein, color: CyberTheme.neonCyan)
                        MacroData(label: "CARB", value: item.carbs, color: CyberTheme.neonPurple)
                        MacroData(label: "FAT", value: item.fat, color: .orange)
                    }
                    .padding()
                    Button(action: {
                        withAnimation(.easeIn(duration: 0.1)) { isExploding = true }
                        userHistory.addItem(item)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { selectedItem = nil } }
                    }) {
                        Text(isExploding ? "CONSUMING..." : "CONSUME").font(.system(.headline, design: .monospaced)).bold().foregroundColor(.black).frame(maxWidth: .infinity).padding().background(isExploding ? Color.clear : CyberTheme.neonCyan).cornerRadius(4).neonGlow(color: isExploding ? Color.clear : CyberTheme.neonCyan)
                    }
                    .disabled(isExploding)
                }
                .padding(24).background(CyberTheme.cardBg).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(CyberTheme.neonCyan, lineWidth: 1)).padding()
                Spacer()
            }
        }
    }
}

struct MacroData: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack {
            Text(label).font(.system(size: 10, design: .monospaced)).bold().foregroundColor(color)
            Text(value).font(.system(.title3, design: .monospaced)).bold().foregroundColor(.white)
        }
        .frame(width: 80, height: 60).background(Color.black).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 1))
    }
}
