import Foundation
import SwiftUI

#if canImport(HealthKit)
import HealthKit

// A manager class to handle all HealthKit-related operations.
@available(macOS 13.0, *)
class HealthKitManager: ObservableObject {
    
    // The central object to manage HealthKit data.
    let healthStore = HKHealthStore()

    /// Requests authorization from the user to read sleep, step, workout, and mindfulness data.
    /// This should be called once when the app starts.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // 1. Define the data types we want to read.
        let typesToRead: Set = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]

        // 2. Check if HealthKit is available on this device.
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            completion(false)
            return
        }

        // 3. Request authorization.
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("Error requesting HealthKit authorization: \(error.localizedDescription)")
            }
            // The completion handler is called on a background thread, so we dispatch to the main thread.
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    /// Fetches the total sleep duration from the last 24 hours.
    /// - Parameter completion: A closure that returns the total sleep time in hours.
    func fetchSleepData(completion: @escaping (Double?) -> Void) {
        // We want to fetch sleep analysis data.
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }

        // We're looking for data from the last 24 hours.
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Sort the results by start date.
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        // Create and execute the query.
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Error fetching sleep data: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let samples = samples as? [HKCategorySample] else {
                completion(nil)
                return
            }

            // Calculate the total duration of "in bed" or "asleep" samples.
            let totalSleepDuration = samples.reduce(0) { (result, sample) -> TimeInterval in
                // CORRECTED: Updated to use modern sleep analysis values.
                if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                    return result + sample.endDate.timeIntervalSince(sample.startDate)
                }
                return result
            }
            
            // Convert the duration from seconds to hours.
            let totalHours = totalSleepDuration / 3600
            completion(totalHours)
        }

        healthStore.execute(query)
    }

    /// Fetches the total step count from the last 24 hours.
    /// - Parameter completion: A closure that returns the total number of steps.
    func fetchStepCount(completion: @escaping (Double?) -> Void) {
        // We want to fetch the step count.
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }

        // We're looking for data from the last 24 hours.
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Create and execute the query for step count.
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Error fetching step count: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            
            // Return the total steps.
            completion(sum.doubleValue(for: .count()))
        }

        healthStore.execute(query)
    }
    
    // Fetches the total duration of workouts from the last 24 hours.
    /// - Parameter completion: A closure that returns the total workout time in minutes.
    func fetchWorkoutDuration(completion: @escaping (Double?) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Error fetching workouts: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let workouts = samples as? [HKWorkout] else {
                completion(nil)
                return
            }

            // Sum the duration of all workouts.
            let totalDuration = workouts.reduce(0) { $0 + $1.duration }
            
            // Convert duration from seconds to minutes.
            let totalMinutes = totalDuration / 60
            completion(totalMinutes)
        }

        healthStore.execute(query)
    }

    // Fetches the total duration of mindful sessions from the last 24 hours.
    /// - Parameter completion: A closure that returns the total mindful time in minutes.
    func fetchMindfulMinutes(completion: @escaping (Double?) -> Void) {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            completion(nil)
            return
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Error fetching mindful sessions: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let sessions = samples as? [HKCategorySample] else {
                completion(nil)
                return
            }

            // Sum the duration of all mindful sessions.
            let totalDuration = sessions.reduce(0) { $0 + ($1.endDate.timeIntervalSince($1.startDate)) }
            
            // Convert duration from seconds to minutes.
            let totalMinutes = totalDuration / 60
            completion(totalMinutes)
        }

        healthStore.execute(query)
    }
}

#else

// Fallback implementation when HealthKit is not available
class HealthKitManager: ObservableObject {
    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(false) }
    func fetchSleepData(completion: @escaping (Double?) -> Void) { completion(nil) }
    func fetchStepCount(completion: @escaping (Double?) -> Void) { completion(nil) }
    func fetchWorkoutDuration(completion: @escaping (Double?) -> Void) { completion(nil) }
    func fetchMindfulMinutes(completion: @escaping (Double?) -> Void) { completion(nil) }
}

#endif
