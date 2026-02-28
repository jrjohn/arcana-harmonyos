/**
 * Injectable User API Service
 * Implements IUserApiService interface for DI container
 */

import { http } from '@kit.NetworkKit';
import { injectable, preDestroy } from '../../core/di/decorators';
import { IUserApiService } from '../../core/di/interfaces';
import { ApiConfig, ApiEndpoints, ApiHeaders, HttpStatus } from './ApiConfig';
import {
  PaginatedUsersResponse,
  SingleUserResponse,
  CreateUserResponseDto,
  UpdateUserResponseDto,
  UserDtoMapper
} from './dto/UserDto';
import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers } from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { InterceptedHttpClient } from '../../core/network/HttpInterceptor';

const TAG = 'UserApiServiceImpl';

/**
 * Injectable user API service implementation
 */
@injectable()
export class UserApiServiceImpl implements IUserApiService {
  private httpClient: InterceptedHttpClient;

  constructor() {
    this.httpClient = new InterceptedHttpClient();
  }

  async getUsers(page: number = 1, perPage: number = 6): Promise<Result<PaginatedUsers, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}?page=${page}&per_page=${perPage}`;

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as PaginatedUsersResponse;
        return ResultFactory.success(UserDtoMapper.toPaginatedDomain(data));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async getUser(userId: number): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.GET,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as SingleUserResponse;
        return ResultFactory.success(UserDtoMapper.toDomain(data.data));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.USERS}`;
    const body = UserDtoMapper.toCreateDto(request);

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.POST,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.CREATED || response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as CreateUserResponseDto;
        return ResultFactory.success(UserDtoMapper.createResponseToDomain(data, request));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(request.id)}`;
    const body = UserDtoMapper.toUpdateDto(request);

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.PUT,
        header: this.getHeaders(),
        extraData: JSON.stringify(body),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.OK) {
        const data = JSON.parse(response.result as string) as UpdateUserResponseDto;
        return ResultFactory.success(UserDtoMapper.updateResponseToDomain(data, request));
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${request.id}`));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    const url = `${ApiConfig.BASE_URL}${ApiEndpoints.userById(userId)}`;

    try {
      const response = await this.httpClient.request(url, {
        method: http.RequestMethod.DELETE,
        header: this.getHeaders(),
        connectTimeout: ApiConfig.TIMEOUT,
        readTimeout: ApiConfig.TIMEOUT
      });

      if (response.responseCode === HttpStatus.NO_CONTENT || response.responseCode === HttpStatus.OK) {
        return ResultFactory.success(undefined);
      } else if (response.responseCode === HttpStatus.NOT_FOUND) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      return ResultFactory.failure(this.handleError(error));
    }
  }

  @preDestroy()
  destroy(): void {
    this.httpClient.destroy();
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Content-Type'] = ApiHeaders.CONTENT_TYPE;
    headers['Accept'] = ApiHeaders.ACCEPT;
    headers[ApiHeaders.API_KEY_HEADER] = ApiConfig.API_KEY;
    return headers;
  }

  private handleError(error: Error | Object): AppError {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      if (message.includes('timeout')) {
        return AppErrorFactory.networkTimeout();
      } else if (message.includes('network') || message.includes('connection')) {
        return AppErrorFactory.noConnection();
      }
      return AppErrorFactory.networkError(error.message, error);
    }
    return AppErrorFactory.unknown();
  }
}
