import Foundation
import SerpApi

@main
struct Demo {
    static func main() async {
        print("SerpApi Swift Demo")
        print("==================")
        
        guard let apiKey = ProcessInfo.processInfo.environment["SERPAPI_KEY"] else {
            print("Error: Please set SERPAPI_KEY environment variable.")
            exit(1)
        }
        
        let client = SerpApiClient(params: ["api_key": apiKey, "engine": "google"])
        
        // 1. Standard Search
        do {
            print("\n1. Standard Search for 'Coffee' in 'Austin, TX'...")
            let results = try await client.search(params: ["q": "Coffee", "location": "Austin, TX"])
            
            if let searchMetadata = results["search_metadata"] as? [String: Any],
               let id = searchMetadata["id"] as? String {
                print("   Search ID: \(id)")
            }
            
            if let organicResults = results["organic_results"] as? [[String: Any]],
               let firstResult = organicResults.first {
                print("   First Result: \(firstResult["title"] ?? "N/A")")
                print("   Link: \(firstResult["link"] ?? "N/A")")
            }
        } catch {
            print("   Error: \(error.localizedDescription)")
        }
        
        // 2. HTML Search
        do {
            print("\n2. HTML Search for 'Coffee'...")
            let html = try await client.html(params: ["q": "Coffee"])
            print("   HTML received (length: \(html.count) chars)")
        } catch {
            print("   Error: \(error.localizedDescription)")
        }
        
        // 3. Location API
        do {
            print("\n3. Location API for 'Austin'...")
            let locations = try await client.location(params: ["q": "Austin", "limit": "3"])
            print("   Found \(locations.count) locations:")
            for loc in locations {
                print("   - \(loc["name"] ?? "N/A") (ID: \(loc["id"] ?? "N/A"))")
            }
        } catch {
            print("   Error: \(error.localizedDescription)")
        }
        
        // 4. Account API
        do {
            print("\n4. Account API...")
            let account = try await client.account()
            print("   Account Email: \(account["account_email"] ?? "N/A")")
            print("   Plan: \(account["plan_name"] ?? "N/A")")
        } catch {
            print("   Error: \(error.localizedDescription)")
        }
        
        // 5. Async / Archive API
        // Note: Real async submission requires params["async"] = "true"
        do {
            print("\n5. Async Search Submission...")
            let asyncParams = ["q": "Tesla", "location": "Austin, TX", "async": "true"]
            let asyncResult = try await client.search(params: asyncParams)
            
            if let searchMetadata = asyncResult["search_metadata"] as? [String: Any],
               let searchID = searchMetadata["id"] as? String {
                print("   Submitted Async Search. ID: \(searchID)")
                
                // In a real app, you would poll or wait. Here we just demonstrate the call.
                // We'll wait a brief moment and try to fetch from archive (might not be ready yet)
                print("   (Waiting 2 seconds...)")
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                
                print("   Fetching from Archive...")
                let archiveResult = try await client.searchArchive(searchID: searchID)
                if let dict = archiveResult as? [String: Any],
                   let metadata = dict["search_metadata"] as? [String: Any] {
                    print("   Archive Status: \(metadata["status"] ?? "N/A")")
                } else {
                     print("   Archive result not a dictionary or invalid.")
                }
            }
        } catch {
            print("   Error: \(error.localizedDescription)")
        }
        
        client.close()
        print("\nDemo finished.")
    }
}
