//
//  MainViewModel.swift
//  NewsAppMVVMRx
//
//  Created by Alexander Milgunov on 30.07.2020.
//  Copyright © 2020 Alexander Milgunov. All rights reserved.
//

import RxSwift
import RxCocoa

protocol MainViewModelType {
    
    associatedtype Input
    associatedtype Output
    
    func transform(input: Input) -> Output
}

final class MainViewModel: MainViewModelType {
    
    private var dataManager: DataManagerType
    private let isLoading = PublishSubject<Bool>()
    private let pageTrigger = BehaviorRelay<Int>(value: 1)
    
    private let disposeBag = DisposeBag()
    
    //MARK: - Inputs
    struct Input {
        let fetchTopTrigger: Driver<Void>
        let reachedBottomTrigger: Driver<Void>
    }
    
    //MARK: - Outputs
    struct Output {
        let isLoading: Driver<Bool>
        let title: Driver<String>
        let cells: Driver<[CellViewModel]>
    }
    
    func transform(input: Input) -> Output {
        
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        // MARK: - Request to data manager
        
        /// pageTrigger -> page #1 when triggered TOP
        input.fetchTopTrigger.asObservable()
            .observeOn(scheduler)
            .map { 1 }
            .bind(to: pageTrigger)
            .disposed(by: disposeBag)

        /// pageTrigger -> page #+1 when triggered BOTTOM
        input.reachedBottomTrigger.asObservable().share()
            .observeOn(scheduler)
            .withLatestFrom(isLoading)
            .filter { !$0 }
            .map { [unowned self] _ in (pageTrigger.value + 1) }
            .bind(to: pageTrigger)
            .disposed(by: disposeBag)
        
        pageTrigger.subscribe(onNext: { print("current page is: \($0)") }).disposed(by: disposeBag)
        
        /// Start isLoading
        pageTrigger
            .map { _ in true }
            .bind(to: isLoading)
            .disposed(by: disposeBag)
        
        /// Request to data manager
        pageTrigger
            .bind(to: dataManager.fetchNewDataTrigger)
            .disposed(by: disposeBag)
        
        
        // MARK: - Receive data from data manager
        
        let observableData = dataManager.observableData.delay(.seconds(2), scheduler: scheduler).share()
        
        let titleDriver = isLoading
            .map { $0 ? "Loading..." : "Newsfeed" }
            .asDriver(onErrorJustReturn: "Something goes wrong...")
        
        let cellsDriver = observableData
            .map { $0.map { CellViewModel(for: $0) } }
            .map { Array(Set($0)).sorted(by: { $0.publishedAt > $1.publishedAt }) }
            .asDriver(onErrorJustReturn: [])
        
        observableData
            .catchErrorJustReturn([])
            .map { _ in false }
            .bind(to: isLoading)
            .disposed(by: disposeBag)
        
        return Output(isLoading: isLoading.asDriver(onErrorJustReturn: false), title: titleDriver, cells: cellsDriver)
    }
    
    init(with manager: DataManagerType) {
        dataManager = manager
    }
}
